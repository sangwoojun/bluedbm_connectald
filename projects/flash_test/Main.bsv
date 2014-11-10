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
import BRAMFIFO::*;
import BRAM::*;
import GetPut::*;
import ClientServer::*;

import Vector::*;
import List::*;

import PortalMemory::*;
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
//import AuroraExtArbiter::*;
//import AuroraExtImport::*;
//import AuroraExtImport117::*;
import AuroraCommon::*;

//import PageCache::*;
import DMABurstHelper::*;
import ControllerTypes::*;
import FlashCtrlVirtex::*;
import FlashEmu::*;

interface FlashRequest;
	method Action readPage(Bit#(32) channel, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) bufidx);
	method Action writePage(Bit#(32) channel, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) bufidx);
	method Action erasePage(Bit#(32) channel, Bit#(32) chip, Bit#(32) block);
	method Action addWriteHostBuffer(Bit#(32) pointer, Bit#(32) offset, Bit#(32) idx);
	method Action addReadHostBuffer(Bit#(32) pointer, Bit#(32) offset, Bit#(32) idx);
	method Action start(Bit#(32) dummy);
	method Action debugDumpReq(Bit#(32) dummy);
endinterface

interface FlashIndication;
	method Action readDone(Bit#(32) rbuf);
	method Action writeDone(Bit#(32) tag);
	method Action reqFlashCmd(Bit#(32) inq, Bit#(32) count);
	method Action hexDump(Bit#(32) data);
	method Action debugDumpResp(Bit#(32) debugDoneCnt, Bit#(32) debugRCntHi, Bit#(32) debugRCntLo);
endinterface

// NumDmaChannels each for flash i/o and emualted i/o
//typedef TAdd#(NumDmaChannels, NumDmaChannels) NumObjectClients;
typedef NumDmaChannels NumObjectClients;

interface MainIfc;
	interface FlashRequest request;
	interface Vector#(NumObjectClients, ObjectReadClient#(WordSz)) dmaReadClient;
	interface Vector#(NumObjectClients, ObjectWriteClient#(WordSz)) dmaWriteClient;
	//interface ObjectReadClient#(WordSz) dmaReadClient;
	//interface ObjectWriteClient#(WordSz) dmaWriteClient;
	interface Aurora_Pins#(4) aurora_fmc1;
	interface Aurora_Clock_Pins aurora_clk_fmc1;
endinterface

module mkMain#(FlashIndication indication, Clock clk250, Reset rst250)(MainIfc);

	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	Integer numDmaChannels = valueOf(NumDmaChannels);

	Reg#(Bool) started <- mkReg(False);

	Reg#(Bit#(16)) debugCmdTag <- mkReg(0);
	Reg#(Bit#(16)) debugCmdBus <- mkReg(0);
	Reg#(Bit#(16)) debugCmdChip <- mkReg(0);
	Reg#(Bit#(16)) debugCmdBlk <- mkReg(0);
	Reg#(Bit#(16)) debugCmdPage <- mkReg(0);
	Reg#(Bit#(16)) debugFreeBuf <- mkReg(0);
	Reg#(Bit#(16)) debugDmaWrInd <- mkReg(0);
	Reg#(Bit#(64)) debugRCnt <- mkReg(0);
	Reg#(Tuple2#(Bit#(128), TagT)) debugRd <- mkRegU();
	Reg#(Bit#(64)) cmdCnt <- mkReg(0);
	Reg#(Bit#(64)) cycleCnt <- mkReg(0);

	GtxClockImportIfc gtx_clk_fmc1 <- mkGtxClockImport;
	`ifdef BSIM
		FlashCtrlVirtexIfc flashCtrl <- mkFlashEmu(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
	`else
		FlashCtrlVirtexIfc flashCtrl <- mkFlashCtrlVirtex(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
	`endif


	rule incCycle;
		cycleCnt <= cycleCnt + 1;
	endrule


// Host memory access start ////////////////////////////////
	Vector#(NumDmaChannels, MemwriteEngineV#(WordSz,1,2)) weV <- replicateM(mkMemwriteEngine);
	Vector#(NumDmaChannels, MemreadEngineV#(WordSz,1,2))  reV <- replicateM(mkMemreadEngine);



	Vector#(NumTags, Reg#(Bit#(TLog#(NumDmaChannels)))) tag2DmaIndTable <- replicateM(mkRegU());
	Vector#(NumDmaChannels, FIFO#(Tuple2#(Bit#(WordSz), TagT))) dmaWriterBufs <- replicateM(mkSizedFIFO(16));
	FIFO#(Bit#(TLog#(NumDmaChannels))) distrIndPipeQ <- mkFIFO();
	FIFO#(Tuple2#(Bit#(128), TagT)) distrDataPipeQ <- mkFIFO();

	rule distrToDMAWriter;
		let rd <- flashCtrl.user.readWord();
		let data = tpl_1(rd);
		let tag = tpl_2(rd);
		let ind = tag2DmaIndTable[tag];
		distrIndPipeQ.enq(ind);
		distrDataPipeQ.enq(rd);
		$display("@%d main.bsv: read rd = %x, tag = %d, dmaInd=%d", cycleCnt, data, tag, ind);
	endrule

	rule distrToDMAWriter2;
		let ind = distrIndPipeQ.first;
		distrIndPipeQ.deq;
		let rd = distrDataPipeQ.first;
		distrDataPipeQ.deq;
		dmaWriterBufs[ind].enq(rd);
		debugRd <= rd;
		debugRCnt <= debugRCnt + 1;
	endrule


/////////////// DMA Writer with page cache //////////////////////////////////////

	Vector#(NumDmaChannels, DMAWriteEngineIfc#(WordSz)) dmaWriters;
	Vector#(NumDmaChannels, FreeBufferClientIfc) dmaWriterFreeBufferClient;
	//MemwriteEngineV#(WordSz,1,NumDmaChannels) we <- mkMemwriteEngine;
	for ( Integer wIdx = 0; wIdx < numDmaChannels; wIdx = wIdx + 1 ) begin
		let we = weV[wIdx];
		let dmaWrBuf = dmaWriterBufs[wIdx];

		//DMAWriteEngineIfc#(WordSz) dmaWriter <- mkDmaWriteEngine(we.writeServers[wIdx], we.dataPipes[wIdx]);
		DMAWriteEngineIfc#(WordSz) dmaWriter <- mkDmaWriteEngine(we.writeServers[0], we.dataPipes[0]);
		dmaWriters[wIdx] = dmaWriter;

		rule dmaWriteData;
			let r = dmaWrBuf.first;
			dmaWrBuf.deq();
			let d = tpl_1(r);
			let t = tpl_2(r);
			//dmaWriter.write(d,zeroExtend(t)); //FIXME DEBUG
		endrule

		dmaWriterFreeBufferClient[wIdx] = dmaWriter.bufClient;
	end
	FreeBufferManagerIfc writeBufMan <- mkFreeBufferManager(dmaWriterFreeBufferClient);

	//Reg#(Bit#(4)) readDoneCounter <- mkReg(0);
	//Reg#(Bit#(32)) rbufBuff <- mkReg(0);
	//Reg#(Bit#(32)) tagBuff <- mkReg(0);

	Reg#(Bit#(32)) debugDoneCnt <- mkReg(0);

	FIFO#(Bit#(8)) writeDoneIndicationQ <- mkFIFO;
	rule dmaWriteDoneCheck;
			let r <- writeBufMan.done;
			writeDoneIndicationQ.enq(r);
			debugDoneCnt <= debugDoneCnt + 1;
			$display( "write page done in %d", r );
	endrule
	rule flushDmaWriteDone;
		let r = writeDoneIndicationQ.first;
		writeDoneIndicationQ.deq;
		indication.readDone(zeroExtend(r));
		$display ( "sending write page done indication %d",r);
	endrule
/////////////////////////////////////////////////////////////////////////////////////


	Vector#(NumDmaChannels, DMAReadEngineIfc#(WordSz)) dmaReaders;
	//MemreadEngineV#(WordSz,1, NumDmaChannels)  re <- mkMemreadEngine;
	FIFO#(Bit#(8)) dmaReadDoneQ <- mkFIFO;
	rule driveDmaReadDone;
		let bufidx = dmaReadDoneQ.first;
		dmaReadDoneQ.deq;
		indication.writeDone(zeroExtend(bufidx));
	endrule
	

	for ( Integer rIdx = 0; rIdx < numDmaChannels; rIdx = rIdx + 1 ) begin
		let re = reV[rIdx];
		//let pageCache = pageCaches[rIdx];

		DMAReadEngineIfc#(WordSz) dmaReader <- mkDmaReadEngine(re.readServers[0], re.dataPipes[0]);
		//DMAReadEngineIfc#(WordSz) dmaReader <- mkDmaReadEngine(re.readServers[rIdx], re.dataPipes[rIdx]);
		dmaReaders[rIdx] = dmaReader;

		rule dmaReadDone;
			let bufidx <- dmaReader.done;
			dmaReadDoneQ.enq(bufidx);
		endrule
		rule dmaReadData;
			let r <- dmaReader.read;
			let d = tpl_1(r);
			let t = tpl_2(r);
			//pageCache.writeWord(d,t);
		endrule
	end // for loop



	Reg#(Bit#(32)) curReqsInQ <- mkReg(0);
	Reg#(Bit#(32)) numReqsRequested <- mkReg(0);
	rule driveNewReqs(started&& curReqsInQ + numReqsRequested < fromInteger(valueOf(NumTags))-48);
		numReqsRequested <= numReqsRequested + 32;
		indication.reqFlashCmd(curReqsInQ, 32);
		//$display( "Requesting more flash commands" );
	endrule

	FIFO#(FlashCmd) flashCmdQ <- mkSizedFIFO(valueOf(NumTags));
	rule driveFlashCmd (started);
		let cmd = flashCmdQ.first;
		flashCmdQ.deq;
		
		Bit#(TLog#(NumDmaChannels)) dmaInd = truncate(cmd.bus);
		//store tag and dmaWrInd in look up table
		tag2DmaIndTable[cmd.tag] <= dmaInd;

		//forward command to flash controller
		flashCtrl.user.sendCmd(cmd);

		//debug
		debugDmaWrInd <= zeroExtend(dmaInd);
		debugCmdTag <= zeroExtend(cmd.tag);
		debugCmdBus <= zeroExtend(cmd.bus);
		debugCmdChip <=zeroExtend(cmd.chip);
		debugCmdBlk <= zeroExtend(cmd.block);
		debugCmdPage <=zeroExtend(cmd.page);
		cmdCnt <= cmdCnt + 1;

		if ( cmd.op == READ_PAGE ) begin
			curReqsInQ <= curReqsInQ -1;

			// temporary stuff
			let dmaWriter = dmaWriters[dmaInd];
			dmaWriter.startWrite(zeroExtend(cmd.tag), fromInteger(pageWords));

			//pageCache.readPage( zeroExtend(cmd.page), cmd.bufidx);
			$display( "starting page read %d at tag %d, bus/dmawriterInd=%d", cmd.page, cmd.tag, dmaInd);
		end
	endrule

	
	FIFO#(Bit#(1)) debugReqQ <- mkFIFO();
	rule doDebugDump;
		$display("Main.bsv: debug dump request received");
		debugReqQ.deq;
		indication.debugDumpResp(debugDoneCnt, debugRCnt[63:32], debugRCnt[31:0]);
	endrule

   
	Vector#(NumObjectClients, ObjectReadClient#(WordSz)) dmaReadClients;
	Vector#(NumObjectClients, ObjectWriteClient#(WordSz)) dmaWriteClients;
	for ( Integer idx = 0; idx < numDmaChannels; idx = idx + 1 ) begin
		dmaReadClients[idx] = reV[idx].dmaClient;
		dmaWriteClients[idx] = weV[idx].dmaClient;
	end
	/*
	for ( Integer idx = 0; idx < numDmaChannels; idx = idx + 1 ) begin
		let iidx = idx + numDmaChannels;
		dmaReadClients[iidx] = reV[idx].dmaClient;
		dmaWriteClients[iidx] = weV[idx].dmaClient;
	end
	*/

   interface FlashRequest request;
	method Action readPage(Bit#(32) channel, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) bufidx);
		FlashCmd fcmd = FlashCmd{
			tag: truncate(bufidx),
			op: READ_PAGE,
			bus: truncate(channel),
			chip: truncate(chip),
			block: truncate(block),
			page: truncate(page)
			};

		flashCmdQ.enq(fcmd);
		curReqsInQ <= curReqsInQ +1;
		numReqsRequested <= numReqsRequested - 1;
	endmethod
	
   method Action writePage(Bit#(32) channel, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) bufidx);
		/*
		CmdType cmd = Write;
		FlashCmd fcmd = FlashCmd{
			channel: truncate(channel),
			chip: truncate(chip),
			block: truncate(block),
			page: truncate(page),
			cmd: cmd,
			bufidx: truncate(bufidx),
			tag: ?};

		flashCmdQ.enq(fcmd);
		curReqsInQ <= curReqsInQ +1;
		numReqsRequested <= numReqsRequested - 1;
		*/
	endmethod
	method Action erasePage(Bit#(32) channel, Bit#(32) chip, Bit#(32) block);
		/*
		CmdType cmd = Erase;
		FlashCmd fcmd = FlashCmd{
			channel: truncate(channel),
			chip: truncate(chip),
			block: truncate(block),
			page: 0,
			cmd: cmd,
			tag: 0};

		flashCmdQ.enq(fcmd);
		curReqsInQ <= curReqsInQ +1;
		numReqsRequested <= numReqsRequested - 1;
		*/
	endmethod

	method Action addWriteHostBuffer(Bit#(32) pointer, Bit#(32) offset, Bit#(32) idx);
		for (Integer i = 0; i < numDmaChannels; i = i + 1) begin
			dmaReaders[i].addBuffer(truncate(idx), offset, pointer);
		end
	endmethod
	method Action addReadHostBuffer(Bit#(32) pointer, Bit#(32) offset, Bit#(32) idx);
		writeBufMan.addBuffer(truncate(offset), pointer);
	endmethod
	method Action start(Bit#(32) datasource);
		started <= True;
	endmethod


	method Action debugDumpReq(Bit#(32) dummy);
		debugReqQ.enq(1);
	endmethod

	endinterface

   interface ObjectReadClient dmaReadClient = dmaReadClients;
   interface ObjectWriteClient dmaWriteClient = dmaWriteClients;

   interface Aurora_Pins aurora_fmc1 = flashCtrl.aurora;
   interface Aurora_Clock_Pins aurora_clk_fmc1 = gtx_clk_fmc1.aurora_clk;

endmodule

