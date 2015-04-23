// Copyright (c) 2013 Quanta Research Cambridge, Inc.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import FIFOF::*;
import FIFO::*;
import FIFOLevel::*;
import BRAMFIFO::*;
import BRAM::*;
import GetPut::*;
import ClientServer::*;

import Vector::*;
import List::*;

import ConnectalMemory::*;
import MemTypes::*;
import MemreadEngine::*;
import MemwriteEngine::*;
import Pipe::*;

import Clocks :: *;
import Xilinx       :: *;
`ifndef BSIM
import XilinxCells ::*;
`endif

import AuroraImportFmc1::*;

import ControllerTypes::*;
import FlashCtrlVirtex::*;
import FlashCtrlModel::*;

import AuroraCommon::*;
import MainTypes::*;

import BRAMFIFOVector::*;

interface FlashRequest;
	method Action readPage(Bit#(32) node, Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) tag);
	method Action writePage(Bit#(32) node, Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) tag);
	method Action eraseBlock(Bit#(32) node, Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) tag);
	method Action setDmaReadRef(Bit#(32) sgId);
	method Action setDmaWriteRef(Bit#(32) sgId);
	method Action start(Bit#(32) dummy);
	method Action debugDumpReq(Bit#(32) dummy);
	method Action setDebugVals (Bit#(32) flag, Bit#(32) debugDelay); 
	method Action setAuroraExtRoutingTable(Bit#(32) node, Bit#(32) portidx, Bit#(32) portsel);
	method Action setNetId(Bit#(32) netid);
	method Action auroraStatus(Bit#(32) dummy);
endinterface

interface FlashIndication;
	method Action readDone(Bit#(32) tag);
	method Action writeDone(Bit#(32) tag);
	method Action eraseDone(Bit#(32) tag, Bit#(32) status);
	method Action debugDumpResp(Bit#(32) debug0, Bit#(32) debug1, Bit#(32) debug2, Bit#(32) debug3, Bit#(32) debug4, Bit#(32) debug5);
	method Action hexDump(Bit#(32) hex);
	method Action debugAuroraExt(Bit#(32) debug0, Bit#(32) debug1, Bit#(32) debug2, Bit#(32) debug3);
endinterface

// NumDmaChannels each for flash i/o and emualted i/o
//typedef TAdd#(NumDmaChannels, NumDmaChannels) NumObjectClients;
//typedef NumDmaChannels NumObjectClients;
typedef 128 DmaBurstBytes; 
Integer dmaBurstBytes = valueOf(DmaBurstBytes);
Integer dmaBurstWords = dmaBurstBytes/wordBytes; //128/16 = 8
Integer dmaBurstsPerPage = (pageSizeUser+dmaBurstBytes-1)/dmaBurstBytes; //ceiling, 65
Integer dmaBurstWordsLast = (pageSizeUser%dmaBurstBytes)/wordBytes; //num bursts in last dma; 2 bursts
Integer pagePadCnt = dmaBurstWords - dmaBurstWordsLast; //6
Integer dmaAllocPageSizeLog = 14; //typically portal alloc page size is 16KB; MUST MATCH SW

interface MainIfc;
	interface FlashRequest request;
	interface Vector#(1, MemWriteClient#(WordSz)) dmaWriteClient;
	interface Vector#(1, MemReadClient#(WordSz)) dmaReadClient;
	interface Aurora_Pins#(4) aurora_fmc1;
	interface Aurora_Clock_Pins aurora_clk_fmc1;
	interface Vector#(AuroraExtCount, Aurora_Pins#(1)) aurora_ext;
	interface Aurora_Clock_Pins aurora_quad119;
endinterface

(*synthesize*)
module mkBRAMFIFOVectorSynth(BRAMFIFOVectorIfc#(TLog#(TAGS_PER_PORT), 12, Tuple2#(Bit#(WordSz), TagT)));
	BRAMFIFOVectorIfc#(TLog#(TAGS_PER_PORT), 12, Tuple2#(Bit#(WordSz), TagT)) bramFifoVec <- mkBRAMFIFOVector(dmaBurstWords, pageWords, pagePadCnt);
	return bramFifoVec;
endmodule

module mkMain#(FlashIndication indication, 
					Clock clk250, Reset rst250)(MainIfc);

	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;


	Reg#(Bool) started <- mkReg(False);
	Reg#(Bit#(64)) cycleCnt <- mkReg(0);


	//Flash Controller
	GtxClockImportIfc gtx_clk_fmc1 <- mkGtxClockImport;
	`ifdef BSIM
		FlashCtrlVirtexIfc flashCtrl <- mkFlashCtrlModel(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
	`else
		FlashCtrlVirtexIfc flashCtrl <- mkFlashCtrlVirtex(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
	`endif


	//Create read/write engines with NUM_BUSES memservers
	MemreadEngineV#(WordSz, 4, NUM_ENG_PORTS) re <- mkMemreadEngine;
	MemwriteEngineV#(WordSz, 2, NUM_ENG_PORTS) we <- mkMemwriteEngine; //Note: Depth >2 causes kernel panics

	
	
	Reg#(Bit#(6)) myNodeId <- mkReg(1); 

	FIFO#(FlashCmdRoute) flashCmdQ <- mkSizedFIFO(valueOf(NumTags));
	FIFO#(FlashCmdRoute) flashCmdLocalQ <- mkFIFO();

	rule incCycle;
		cycleCnt <= cycleCnt + 1;
	endrule

	rule flashCmdForward if (started);
		let cmdRoute = flashCmdQ.first;
		flashCmdQ.deq;
		flashCmdLocalQ.enq(cmdRoute);
	endrule

	rule insertTagTable;
		flashCmdLocalQ.deq;
		let cmdRt = flashCmdLocalQ.first;
		flashCtrl.user.sendCmd(cmdRt.fcmd); //forward cmd to flash ctrl
		let cmd = cmdRt.fcmd;
		$display("[%d] @%d: Main.bsv: received cmd tag=%d @%x %x %x %x", myNodeId, 
						cycleCnt, cmd.tag, cmd.bus, cmd.chip, cmd.block, cmd.page);
	endrule



	Reg#(Bit#(32)) delayRegSet <- mkReg(0);
	Reg#(Bit#(8)) delayReg <- mkReg(0);
	Reg#(Bit#(32)) debugFlag <- mkReg(0);
	Reg#(Bit#(32)) debugReadCnt <- mkReg(0);
	Reg#(Bit#(32)) debugWriteCnt <- mkReg(0);


	//--------------------------------------------
	// Reads from Flash (DMA Write)
	//--------------------------------------------
	Reg#(Bit#(32)) dmaWriteSgid <- mkReg(0);
	//each bram fifo vec is responsible for NumTags/NUM_ENG_PORTS = 128/8 = 16 tags
	Vector#(NUM_ENG_PORTS, BRAMFIFOVectorIfc#(TLog#(TAGS_PER_PORT), 12, Tuple2#(Bit#(WordSz), TagT))) bramFifoVec <- replicateM(mkBRAMFIFOVectorSynth());
	Vector#(NUM_ENG_PORTS, FIFO#(Tuple2#(TagT, Bit#(32)))) dmaReq2RespQ <- replicateM(mkSizedFIFO(16)); //TODO sz?
	Vector#(NUM_ENG_PORTS, FIFO#(MemengineCmd)) dmaWriteReqQ <- replicateM(mkSizedFIFO(16));
	Vector#(NUM_ENG_PORTS, FIFO#(TagT)) dmaWriteDoneQs <- replicateM(mkFIFO);
	FIFO#(Tuple2#(Bit#(WordSz), TagT)) dataFlash2FifoVecQ <- mkFIFO();

	function Tuple2#(Bit#(TLog#(TAGS_PER_PORT)), Bit#(TLog#(NUM_ENG_PORTS))) decTag(TagT tag);
		Bit#(TLog#(NUM_ENG_PORTS)) engPortSel = truncate(tag);
		Bit#(TLog#(TAGS_PER_PORT)) idx = truncate(tag>>log2(num_eng_ports));
		return tuple2(idx, engPortSel);
	endfunction

	function TagT encTag(Bit#(TLog#(TAGS_PER_PORT)) idx, Bit#(TLog#(NUM_ENG_PORTS)) engPort);
		TagT tmpIdx = zeroExtend(idx);
		TagT tmpEp = zeroExtend(engPort);
		TagT tag = (tmpIdx<<log2(num_eng_ports)) | tmpEp;
		return tag;
	endfunction

	function Bit#(32) calcDmaPageOffset(TagT tag);
		Bit#(32) off = zeroExtend(tag);
		return (off<< dmaAllocPageSizeLog);
	endfunction


	rule doEnqReadFromFlash;
		if (delayReg==0) begin
			let taggedRdata <- flashCtrl.user.readWord();
			debugReadCnt <= debugReadCnt + 1;
			if (debugFlag==0) begin
				dataFlash2FifoVecQ.enq(taggedRdata);
			end
			delayReg <= truncate(delayRegSet);
		end
		else begin
			delayReg <= delayReg - 1;
		end
	endrule

	rule doDistrReadFromFlash;
		let taggedRdata = dataFlash2FifoVecQ.first;
		dataFlash2FifoVecQ.deq;
		match{.data, .tag} = taggedRdata;
		match{.idx, .sel} = decTag(tag);
		bramFifoVec[sel].enq(taggedRdata, idx);
		$display("[%d] @%d Main.bsv: flash read sel=%d, idx=%d, tag=%d, data=%x", myNodeId, 
						cycleCnt, sel, idx, tag, data);
	endrule

	//connect output of bramfifovecs with WE port
	for (Integer p=0; p<num_eng_ports; p=p+1) begin
		rule createDmaWriteReq;
			let rdyIdxCnt <- bramFifoVec[p].getReadyIdx();
			match{.rdyIdx, .rdyCnt} = rdyIdxCnt;
			//req DMA
			TagT tag = encTag(rdyIdx, fromInteger(p));
			Bit#(32) pageOffset = calcDmaPageOffset(tag);
			Bit#(32) burstOffset = (rdyCnt<<log2(dmaBurstBytes)) + pageOffset;
			let dmaCmd = MemengineCmd {
								sglId: dmaWriteSgid, 
								base: zeroExtend(burstOffset),
								len:fromInteger(dmaBurstBytes), 
								burstLen:fromInteger(dmaBurstBytes)
							};
			bramFifoVec[p].reqDeq(rdyIdx);
			dmaWriteReqQ[p].enq(dmaCmd);
			dmaReq2RespQ[p].enq(tuple2(tag, rdyCnt));
			$display("[%d] @%d Main.bsv: init dma write rdyIdx=%d, rdyCnt=%d, engId=%d, tag=%d, addr=0x%x 0x%x", myNodeId, 
							cycleCnt, rdyIdx, rdyCnt, p, tag, dmaWriteSgid, burstOffset);

		endrule

		rule issueDmaReq;
			we.writeServers[p].request.put(dmaWriteReqQ[p].first);
			dmaWriteReqQ[p].deq;
		endrule

		rule sendDmaWrites;
			let data <- bramFifoVec[p].respDeq();
			we.dataPipes[p].enq(tpl_1(data));
			//$display("[%d] @%d Main.bsv: sendDmaWrites engId=%d,tag=%d data=%x ", myNodeId, 
			//				cycleCnt, p, tpl_2(data), tpl_1(data));
		endrule


		//dma response.get done; when enough has accumulated, send ack to sw
		rule dmaWriterGetResponse;
			let dummy <- we.writeServers[p].response.get;
			match{.tag, .idxCnt} = dmaReq2RespQ[p].first;
			dmaReq2RespQ[p].deq;
			$display("[%d] @%d Main.bsv: dma resp [%d] tag=%d", myNodeId, cycleCnt, idxCnt, tag);
			if ( idxCnt==fromInteger(dmaBurstsPerPage-1)) begin
				dmaWriteDoneQs[p].enq(tag);
			end
		endrule

		rule collectReadDone;
			dmaWriteDoneQs[p].deq;
			let tag = dmaWriteDoneQs[p].first;
			indication.readDone(zeroExtend(tag));
		endrule

	end



	//--------------------------------------------
	// Writes to Flash (DMA Reads)
	//--------------------------------------------
	Reg#(Bit#(32)) dmaReadSgid <- mkReg(0);
	Vector#(NUM_ENG_PORTS, FIFO#(TagT)) dmaRdReq2RespQ <- replicateM(mkSizedFIFO(4)); //TODO sz
	Vector#(NUM_ENG_PORTS, Reg#(Bit#(32))) dmaReadBurstCount <- replicateM(mkReg(0));
	Vector#(NUM_ENG_PORTS, FIFO#(TagT)) dmaReadReqQ <- replicateM(mkSizedFIFO(4));
	Vector#(NUM_ENG_PORTS, Reg#(Bit#(32))) dmaRdReqCnts <- replicateM(mkReg(0));
	Reg#(Bit#(TLog#(NUM_ENG_PORTS))) reSel <- mkReg(0);

	//Handle write data requests from controller
	rule handleWriteDataRequestFromFlash;
		TagT tag <- flashCtrl.user.writeDataReq();
		$display("[%d] Main.bsv: writeDataReq received from controller tag=%d", myNodeId,tag);
		dmaReadReqQ[reSel].enq(tag);
		dmaRdReq2RespQ[reSel].enq(tag);
		//round robin through the REs
		if (reSel == fromInteger(num_eng_ports-1)) begin
			reSel <= 0;
		end
		else begin
			reSel <= reSel + 1;
		end
	endrule

	for (Integer p=0; p<num_eng_ports; p=p+1) begin

		rule issueDmaRead; 
			//for each req in dmaReadReqQ, read the entire page
			let tag = dmaReadReqQ[p].first;
			Bit#(32) pageOffset = calcDmaPageOffset(tag);
			Bit#(32) burstOffset = (dmaRdReqCnts[p]<<log2(dmaBurstBytes)) + pageOffset;
			let dmaCmd = MemengineCmd {
								sglId: dmaReadSgid, 
								base: zeroExtend(burstOffset),
								len:fromInteger(dmaBurstBytes), 
								burstLen:fromInteger(dmaBurstBytes)
							};
			re.readServers[p].request.put(dmaCmd);
			$display("[%d] Main.bsv: dma read cmd issued: tag=%d base=%x, burstOffset=%d", myNodeId, tag, dmaReadSgid, burstOffset);
			if (dmaRdReqCnts[p] == fromInteger(dmaBurstsPerPage-1)) begin
				dmaRdReqCnts[p] <= 0;
				dmaReadReqQ[p].deq; //done with this req
			end
			else begin
				dmaRdReqCnts[p] <= dmaRdReqCnts[p] + 1;
			end
		endrule

		rule dmaReaderGetResponse;
			let dummy <- re.readServers[p].response.get;
		endrule

		//forward data
		FIFO#(Tuple2#(Bit#(128), TagT)) writeWordPipe <- mkFIFO();
		rule pipeDmaRdData;
			let d <- toGet(re.dataPipes[p]).get;
			let tag = dmaRdReq2RespQ[p].first;
			if (dmaReadBurstCount[p] < fromInteger(pageWords)) begin
				writeWordPipe.enq(tuple2(d, tag));
				$display("[%d] Main.bsv: forwarded dma read data [%d]: tag=%d, data=%x", 
					myNodeId, dmaReadBurstCount[p], tag, d);
			end
			else begin 
				//drop the data because it's just 0 padded
				$display("[%d] Main.bsv: dropped dma read data[%d]", myNodeId, dmaReadBurstCount[p]);
			end

			if (dmaReadBurstCount[p] == fromInteger(dmaBurstsPerPage*dmaBurstWords-1)) begin
				dmaRdReq2RespQ[p].deq;
				dmaReadBurstCount[p] <= 0;
			end
			else begin
				dmaReadBurstCount[p] <= dmaReadBurstCount[p] + 1;
			end
		endrule

		rule forwardDmaRdData;
			writeWordPipe.deq;
			debugWriteCnt <= debugWriteCnt + 1;
			flashCtrl.user.writeWord(writeWordPipe.first);
		endrule
			
	end //for each bus

	//--------------------------------------------
	// Writes/Erase Acks
	//--------------------------------------------

	//Handle acks from controller
	FIFO#(Tuple2#(TagT, StatusT)) ackQ <- mkFIFO;
	rule handleControllerAck;
		let ackStatus <- flashCtrl.user.ackStatus();
		match{.tag, .status} = ackStatus;
		ackQ.enq(ackStatus);
	endrule

	rule indicateControllerAck;
		ackQ.deq;
		TagT tag = tpl_1(ackQ.first);
		StatusT st = tpl_2(ackQ.first);
		case (st)
			WRITE_DONE: indication.writeDone(zeroExtend(tag));
			ERASE_DONE: indication.eraseDone(zeroExtend(tag), 0);
			ERASE_ERROR: indication.eraseDone(zeroExtend(tag), 1);
		endcase
	endrule


	//--------------------------------------------
	// Debug
	//--------------------------------------------

	FIFO#(Bit#(1)) debugReqQ <- mkFIFO();
	rule doDebugDump;
		$display("[%d] Main.bsv: debug dump request received", myNodeId);
		debugReqQ.deq;
		let debugCnts = flashCtrl.debug.getDebugCnts(); 
		let gearboxSendCnt = tpl_1(debugCnts);         
		let gearboxRecCnt = tpl_2(debugCnts);   
		let auroraSendCntCC = tpl_3(debugCnts);     
		let auroraRecCntCC = tpl_4(debugCnts);  
		indication.debugDumpResp(gearboxSendCnt, gearboxRecCnt, auroraSendCntCC, auroraRecCntCC, debugReadCnt, debugWriteCnt);
	endrule



	Vector#(1, MemWriteClient#(WordSz)) dmaWriteClientVec;
	Vector#(1, MemReadClient#(WordSz)) dmaReadClientVec;
	dmaWriteClientVec[0] = we.dmaClient;
	dmaReadClientVec[0] = re.dmaClient;
		

   interface FlashRequest request;
		method Action readPage(Bit#(32) node, Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) tag);
			FlashCmd fcmd = FlashCmd{
				tag: truncate(tag),
				op: READ_PAGE,
				bus: truncate(bus),
				chip: truncate(chip),
				block: truncate(block),
				page: truncate(page)
				};

			flashCmdQ.enq(FlashCmdRoute{srcNode: myNodeId, dstNode: truncate(node), fcmd: fcmd});
		endmethod
		
		method Action writePage(Bit#(32) node, Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) tag);
			FlashCmd fcmd = FlashCmd{
				tag: truncate(tag),
				op: WRITE_PAGE,
				bus: truncate(bus),
				chip: truncate(chip),
				block: truncate(block),
				page: truncate(page)
				};
			flashCmdQ.enq(FlashCmdRoute{srcNode: myNodeId, dstNode: truncate(node), fcmd: fcmd});
		endmethod

		method Action eraseBlock(Bit#(32) node, Bit#(32) bus, Bit#(32) chip, Bit#(32) block, Bit#(32) tag);
			FlashCmd fcmd = FlashCmd{
				tag: truncate(tag),
				op: ERASE_BLOCK,
				bus: truncate(bus),
				chip: truncate(chip),
				block: truncate(block),
				page: 0
				};
			flashCmdQ.enq(FlashCmdRoute{srcNode: myNodeId, dstNode: truncate(node), fcmd: fcmd});
		endmethod

		method Action setDmaReadRef(Bit#(32) sgId);
			dmaReadSgid <= sgId;
		endmethod

		method Action setDmaWriteRef(Bit#(32) sgId);
			dmaWriteSgid <= sgId;
		endmethod

		method Action start(Bit#(32) dummy);
			started <= True;
		endmethod

		method Action debugDumpReq(Bit#(32) dummy);
			debugReqQ.enq(1);
		endmethod

		method Action setDebugVals (Bit#(32) flag, Bit#(32) debugDelay); 
			delayRegSet <= debugDelay;
			debugFlag <= flag;
		endmethod


		method Action setAuroraExtRoutingTable(Bit#(32) node, Bit#(32) portidx, Bit#(32) portsel);
		endmethod

		method Action setNetId(Bit#(32) netid);
			myNodeId <= truncate(netid);
		endmethod

		method Action auroraStatus(Bit#(32) dummy);
		endmethod
	endinterface //FlashRequest



   interface MemWriteClient dmaWriteClient = dmaWriteClientVec;
   interface MemReadClient dmaReadClient = dmaReadClientVec;

	
   interface Aurora_Pins aurora_fmc1 = flashCtrl.aurora;
   interface Aurora_Clock_Pins aurora_clk_fmc1 = gtx_clk_fmc1.aurora_clk;

endmodule








