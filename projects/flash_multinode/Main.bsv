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


import ControllerTypes::*;
import FlashCtrlVirtex::*;
import FlashCtrlModel::*;

import AuroraImportFmc1::*;
import AuroraCommon::*;
import AuroraExtArbiterBar::*;
import AuroraExtEndpoint::*;
import AuroraExtImport::*;

import MainTypes::*;

import BRAMFIFOVector::*;
import FlashSplitter::*;

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

	interface Vector#(AuroraExtPerQuad, Aurora_Pins#(1)) aurora_ext;
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
	MemreadEngine#(WordSz, 4, NUM_ENG_PORTS) re <- mkMemreadEngine;
	MemwriteEngine#(WordSz, 2, NUM_ENG_PORTS) we <- mkMemwriteEngine;


	//External Aurora
	`ifndef BSIM
		ClockDividerIfc auroraExtClockDiv5 <- mkDCMClockDivider(5, 4, clocked_by clk250);
		Clock clk50 = auroraExtClockDiv5.slowClock;
	`else
		Clock clk50 = curClk;
	`endif
	GtxClockImportIfc gtx_clk_119 <- mkGtxClockImport;
	AuroraExtIfc auroraExt119 <- mkAuroraExt(gtx_clk_119.gtx_clk_p_ifc, gtx_clk_119.gtx_clk_n_ifc, clk50);
	
	Reg#(HeaderField) myNodeId <- mkReg(0); 
	AuroraEndpointIfc#(Tuple2#(Bit#(WordSz), TagT)) aendRd <- mkAuroraEndpointDynamic(256, 256, 768);
	AuroraEndpointIfc#(Tuple2#(Bit#(WordSz), TagT)) aendWd <- mkAuroraEndpointDynamic(256, 256, 768);
	AuroraEndpointIfc#(FlashCmdRoute) aendFcmd <- mkAuroraEndpointDynamic(4, 2, 32);
	AuroraEndpointIfc#(Tuple2#(TagT, StatusT)) aendAck <- mkAuroraEndpointDynamic(4, 2, 32);
	AuroraEndpointIfc#(WdReqT) aendWreq <- mkAuroraEndpointDynamic(4, 2, 32);

	let auroraList = cons(aendFcmd.cmd, cons(aendAck.cmd, cons(aendWreq.cmd, cons(aendWd.cmd, cons(aendRd.cmd, nil)))));
	AuroraExtArbiterBarIfc auroraExtArbiter <- mkAuroraExtArbiterBar(auroraExt119.user, auroraList);
	

	//--------------------------------------------
	// External Aurora Send/receive
	//--------------------------------------------

	FlashSplitterIfc flashSplit <- mkFlashSplitter();

	rule sendRemoteFlashCmd;
		let cmd <- flashSplit.remFlashCli.sendCmd.get();
		aendFcmd.user.send(cmd, cmd.dstNode);
		let fcmd = cmd.fcmd;
		$display("[%d] @%d: Main.bsv: sent REMOTE cmd dstnode=%d, tag=%d @%x %x %x %x", myNodeId,  
						cycleCnt, cmd.dstNode, fcmd.tag, fcmd.bus, fcmd.chip, fcmd.block, fcmd.page);
	endrule

	rule recRemoteFlashCmd;
		let cmdSrc <- aendFcmd.user.receive;
		let cmd = tpl_1(cmdSrc);
		flashSplit.remFlashServ.sendCmd.put(cmd);
		let fcmd = cmd.fcmd;
		$display("[%d] @%d: Main.bsv: recv REMOTE cmd dstnode=%d, tag=%d @%x %x %x %x", myNodeId,  
						cycleCnt, cmd.dstNode, fcmd.tag, fcmd.bus, fcmd.chip, fcmd.block, fcmd.page);
	endrule

	rule sendRemoteRdata;
		let d <- flashSplit.remFlashServ.readWord.get();
		match{.data, .tag, .dst} = d;
		aendRd.user.send(tuple2(data, tag), dst);
		//$display("[%d] @%d: Main.bsv: sent REMOTE data dstnode=%d, tag=%d data=%x", myNodeId,  
		//				cycleCnt, dst, tag, data);
	endrule

	rule recRemoteRdata;
		let dSrc <- aendRd.user.receive;
		match{.d, .src} = dSrc;
		match{.data, .tag} = d;
		flashSplit.remFlashCli.readWord.put(tuple3(data, tag, src));
		//$display("[%d] @%d: Main.bsv: recv REMOTE data from srcnode=%d, tag=%d data=%x", myNodeId,  
		//				cycleCnt, src, tag, data);
	endrule

	rule sendRemoteWdata;
		let d <- flashSplit.remFlashCli.writeWord.get();
		match{.data, .tag, .dst} = d;
		aendWd.user.send(tuple2(data, tag), dst);
		//$display("[%d] @%d: Main.bsv: sent REMOTE WRITE data dstnode=%d, tag=%d data=%x", myNodeId,  
		//				cycleCnt, dst, tag, data);
	endrule

	rule recRemoteWdata;
		let dSrc <- aendWd.user.receive;
		match{.datatag, .src} = dSrc;
		match{.data, .tag} = datatag;
		flashSplit.remFlashServ.writeWord.put(tuple3(data, tag, src));
	endrule


	rule sendRemoteAck;
		let d <- flashSplit.remFlashServ.ackStatus.get();
		match{.tag, .stat, .dst} = d;
		aendAck.user.send(tuple2(tag, stat), dst);
		$display("[%d] @%d: Main.bsv: sent REMOTE ACK dstnode=%d, tag=%d stat=%x", myNodeId,  
						cycleCnt, dst, tag, stat);
	endrule

	rule recRemoteAck;
		let dSrc <- aendAck.user.receive;
		match{.ack, .src} = dSrc;
		match{.tag, .stat} = ack;
		flashSplit.remFlashCli.ackStatus.put(tuple3(tag, stat, src));
		$display("[%d] @%d: Main.bsv: recv REMOTE ACK from srcnode=%d, tag=%d stat=%x", myNodeId,  
						cycleCnt, src, tag, stat);
	endrule


	rule sendRemoteWreq;
		let req <- flashSplit.remFlashServ.writeDataReq.get();
		aendWreq.user.send(req, req.dst);
		$display("[%d] @%d: Main.bsv: sent REMOTE WREQ dstnode=%d, origtag=%d, retag=%d", myNodeId,  
						cycleCnt, req.dst, req.origTag, req.reTag);
	endrule

	rule recRemoteWreq;
		let reqSrc <- aendWreq.user.receive;
		match{.req, .trash} = reqSrc;
		flashSplit.remFlashCli.writeDataReq.put(req);
		$display("[%d] @%d: Main.bsv: recv REMOTE WREQ from srcnode=%d, origtag=%d, retag=%d", myNodeId,  
						cycleCnt, req.src, req.origTag, req.reTag);
	endrule
	



	FIFO#(FlashCmdRoute) flashCmdQ <- mkSizedBRAMFIFO(valueOf(NumTags));
	FIFO#(FlashCmdRoute) flashCmdLocalQ <- mkFIFO();

	rule incCycle;
		cycleCnt <= cycleCnt + 1;
	endrule

	rule flashCmdForward if (started);
		let cmdRt = flashCmdQ.first;
		flashCmdQ.deq;
		flashSplit.locFlashServ.sendCmd.put(cmdRt);
		let cmd = cmdRt.fcmd;
		$display("[%d] @%d: Main.bsv: received cmd origtag=%d @%x %x %x %x", myNodeId, 
						cycleCnt, cmd.tag, cmd.bus, cmd.chip, cmd.block, cmd.page);
	endrule

	rule issueFlashCmd;
		let cmdRt <- flashSplit.locFlashCli.sendCmd.get();
		//flashCmdLocalQ.deq;
		//let cmdRt = flashCmdLocalQ.first;
		flashCtrl.user.sendCmd(cmdRt.fcmd); //forward cmd to flash ctrl
		let cmd = cmdRt.fcmd;
		$display("[%d] @%d: Main.bsv: renamed cmd retag=%d @%x %x %x %x", myNodeId, 
						cycleCnt, cmd.tag, cmd.bus, cmd.chip, cmd.block, cmd.page);
	endrule


	Reg#(Bit#(32)) delayRegSet <- mkReg(0);
	Reg#(Bit#(8)) delayReg <- mkReg(0);
	Reg#(Bit#(1)) debugFlag <- mkReg(0);
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
	//FIFO#(Tuple2#(Bit#(WordSz), TagT)) dataFlash2FifoVecQ <- mkFIFO();

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
			match{.data, .tag} = taggedRdata;
			debugReadCnt <= debugReadCnt + 1;
			if (debugFlag==0) begin
				//dataFlash2FifoVecQ.enq(taggedRdata);
				flashSplit.locFlashCli.readWord.put(tuple3(data, tag, ?));
			end
			delayReg <= truncate(delayRegSet);
		end
		else begin
			delayReg <= delayReg - 1;
		end
	endrule

	rule doDistrReadFromFlash;
		let dataTagDst <- flashSplit.locFlashServ.readWord.get();
		match{.data, .tag, .dst} = dataTagDst;
		let taggedRdata = tuple2(data, tag);
		//let taggedRdata = dataFlash2FifoVecQ.first;
		//dataFlash2FifoVecQ.deq;
		//match{.data, .tag} = taggedRdata;
		match{.idx, .sel} = decTag(tag);
		bramFifoVec[sel].enq(taggedRdata, idx);
		//$display("[%d] @%d Main.bsv: flash read sel=%d, idx=%d, tag=%d, data=%x", myNodeId, 
		//				cycleCnt, sel, idx, tag, data);
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
			//$display("[%d] @%d Main.bsv: dma resp [%d] tag=%d", myNodeId, cycleCnt, idxCnt, tag);
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
	Vector#(NUM_ENG_PORTS, FIFO#(Tuple2#(TagT, HeaderField))) dmaRdReq2RespQ <- replicateM(mkSizedFIFO(4)); //TODO sz
	Vector#(NUM_ENG_PORTS, Reg#(Bit#(32))) dmaReadBurstCount <- replicateM(mkReg(0));
	Vector#(NUM_ENG_PORTS, FIFO#(TagT)) dmaReadReqQ <- replicateM(mkSizedFIFO(4));
	Vector#(NUM_ENG_PORTS, Reg#(Bit#(32))) dmaRdReqCnts <- replicateM(mkReg(0));
	Reg#(Bit#(TLog#(NUM_ENG_PORTS))) reSel <- mkReg(0);

	rule locWriteReq;
		TagT tag <- flashCtrl.user.writeDataReq();
		$display("[%d] Main.bsv: writeDataReq received from controller tag=%d", myNodeId,tag);
		WdReqT req = WdReqT{origTag: ?, reTag: tag, src: ?, dst: ?};
		flashSplit.locFlashCli.writeDataReq.put(req);
	endrule


	//Handle write data requests
	rule handleWriteDataRequestFromFlash;
		let req <- flashSplit.locFlashServ.writeDataReq.get();

		dmaReadReqQ[reSel].enq(req.origTag); //use original tag to get DMA data
		//use renamed tag when forwarding bursts; req src is dst of bursts
		dmaRdReq2RespQ[reSel].enq(tuple2(req.reTag, req.src)); 
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
		FIFO#(Tuple3#(Bit#(128), TagT, HeaderField)) writeWordPipe <- mkFIFO();
		rule pipeDmaRdData;
			let d <- toGet(re.dataPipes[p]).get;
			match{.retag, .dst} = dmaRdReq2RespQ[p].first;
			if (dmaReadBurstCount[p] < fromInteger(pageWords)) begin
				writeWordPipe.enq(tuple3(d, retag, dst));
				//$display("[%d] Main.bsv: forwarded dma read data [%d]: retag=%d, data=%x", 
				//	myNodeId, dmaReadBurstCount[p], retag, d);
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
			flashSplit.locFlashServ.writeWord.put(writeWordPipe.first);
			//flashCtrl.user.writeWord(writeWordPipe.first);
		endrule
			
	end //for each engine port

	//local write data
	rule locWriteData;
		let d <- flashSplit.locFlashCli.writeWord.get();
		flashCtrl.user.writeWord(tuple2(tpl_1(d), tpl_2(d)));
	endrule


	//--------------------------------------------
	// Writes/Erase Acks
	//--------------------------------------------

	rule locAck;
		let ackStatus <- flashCtrl.user.ackStatus();
		match{.tag, .status} = ackStatus;
		flashSplit.locFlashCli.ackStatus.put(tuple3(tag, status, ?));
	endrule
		
	//Handle acks from controller
	FIFO#(Tuple2#(TagT, StatusT)) ackQ <- mkFIFO;
	rule handleControllerAck;
		let ackStatus <- flashSplit.locFlashServ.ackStatus.get();
		match{.tag, .status, .trash} = ackStatus;
		ackQ.enq(tuple2(tag, status));
	endrule

	rule indicateControllerAck;
		ackQ.deq;
		match{.tag, .st} = ackQ.first;
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
			//dmaReadRefs[tag] <= tuple2(pointer, offset);
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
			debugFlag <= truncate(flag);
		endmethod


		method Action setAuroraExtRoutingTable(Bit#(32) node, Bit#(32) portidx, Bit#(32) portsel);
			//auroraExtArbiter.setRoutingTable(truncate(node), truncate(portidx), truncate(portsel));
		endmethod

		method Action setNetId(Bit#(32) netid);
			myNodeId <= truncate(netid);
			auroraExtArbiter.setMyId(truncate(netid));
			auroraExt119.setNodeIdx(truncate(netid));
			flashSplit.setNodeId(truncate(netid));
		endmethod

		method Action auroraStatus(Bit#(32) dummy);
			indication.hexDump({
				0,
				auroraExt119.user[3].channel_up,
				auroraExt119.user[2].channel_up,
				auroraExt119.user[1].channel_up,
				auroraExt119.user[0].channel_up
			});
		endmethod
	endinterface //FlashRequest

   interface MemWriteClient dmaWriteClient = dmaWriteClientVec;
   interface MemReadClient dmaReadClient = dmaReadClientVec;
	
   interface Aurora_Pins aurora_fmc1 = flashCtrl.aurora;
   interface Aurora_Clock_Pins aurora_clk_fmc1 = gtx_clk_fmc1.aurora_clk;

	interface Aurora_Pins aurora_ext = auroraExt119.aurora;
	interface Aurora_Clock_Pins aurora_quad119 = gtx_clk_119.aurora_clk;
endmodule








