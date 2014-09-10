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

import PortalMemory::*;
import MemTypes::*;
import MemreadEngine::*;
import MemwriteEngine::*;
import Pipe::*;

import AuroraImportFmc1::*;
import PageCache::*;
import BRAMFIFOVector::*;


interface FlashRequest;
	method Action readPage(Bit#(32) channel, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) tag);
	method Action writePage(Bit#(32) channel, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) tag);
	method Action erasePage(Bit#(32) channel, Bit#(32) chip, Bit#(32) block);
	method Action sendTest(Bit#(32) data);
	method Action addWriteHostBuffer(Bit#(32) pointer, Bit#(32) idx);
	method Action addReadHostBuffer(Bit#(32) pointer, Bit#(32) idx);
endinterface

interface FlashIndication;
	method Action readDone(Bit#(32) tag);
	method Action writeDone(Bit#(32) tag);
	method Action hexDump(Bit#(32) data);
endinterface

interface MainIfc;
	interface FlashRequest request;
	interface ObjectReadClient#(128) dmaReadClient;
	interface ObjectWriteClient#(128) dmaWriteClient;

	interface Aurora_Pins#(4) aurora_fmc1;
	interface Aurora_Clock_Pins aurora_clk_fmc1;
endinterface

typedef enum {Read,Write,Erase} CmdType deriving (Bits,Eq);
typedef struct { Bit#(5) channel; Bit#(5) chip; Bit#(8) block; Bit#(8) page; CmdType cmd; Bit#(8) tag;} FlashCmd deriving (Bits,Eq);

typedef 8192 PageBytes;
typedef 16 WordBytes;
typedef 128 BufferCount;

module mkMain#(FlashIndication indication, Clock clk250, Reset rst250)(MainIfc);
	
	Integer pageBytes = valueOf(PageBytes);
	Integer wordBytes = valueOf(WordBytes); //128 bits
	Integer pageWords = pageBytes/wordBytes;
	Integer bufferCount = valueOf(BufferCount);

	GtxClockImportIfc gtx_clk_fmc1 <- mkGtxClockImport;
	AuroraIfc auroraIntra1 <- mkAuroraIntra(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
   
   BRAMFIFOVectorIfc#(7, 32, Bit#(128)) writeBuffer <- mkBRAMFIFOVector(4);

/*
	Reg#(Bit#(16)) curTestData <- mkReg(0);
	rule sendTestData(curTestData < 16);
		auroraIntra1.send(zeroExtend({16'hbd, curTestData}));
		curTestData <= curTestData + 1;
	endrule
	*/
	FIFO#(Bit#(32)) dataQ <- mkSizedFIFO(32);
	rule recvTestData;
		let datao <- auroraIntra1.receive;
		let data = tpl_1(datao);
		let ptype = tpl_2(datao);
		//writeBuffer.enq(truncate(data), 16);

		dataQ.enq({2'b0,ptype,data[23:0]});
	endrule
	rule dumpD;
		dataQ.deq;
		let data = dataQ.first;
		//writeBuffer.deq(16);
		//let data <- writeBuffer.first(16);

		indication.hexDump(truncate(data));
	endrule

   MemreadEngine#(128,1)  re <- mkMemreadEngine;
   MemwriteEngine#(128,1) we <- mkMemwriteEngine;

   Reg#(Bit#(32))        rdIterCnt <- mkReg(0);
   Reg#(Bit#(32))        wrIterCnt <- mkReg(0);
   Reg#(Bit#(32))            rdCnt <- mkReg(0);
   Reg#(Bit#(32))            wrCnt <- mkReg(0);
   Reg#(ObjectPointer)      rdPointer <- mkReg(0);
   Reg#(ObjectPointer)      wrPointer <- mkReg(0);
   Reg#(Bit#(32))         burstLen <- mkReg(0);
   Reg#(Bit#(32))         numWords <- mkReg(0);
   
   FIFOF#(Bit#(64))    buffer <- mkSizedBRAMFIFOF(16);
   Reg#(Bit#(32))    rdBuffer <- mkReg(32);
   Reg#(Bit#(32))    wrBuffer <- mkReg(0); 
   

   
   rule read_finish;
      let rv0 <- re.readServers[0].response.get;
   endrule

   rule write_finish;
	   let rv1 <- we.writeServers[0].response.get;
	 //indication.done(0);
   endrule

   PageCacheIfc#(3) pageCache <- mkPageCache; // 8 pages
   FIFO#(Bit#(8)) readBufferFreeQ <- mkSizedFIFO(bufferCount); // bufidx
   FIFO#(Bit#(8)) writeBufferFreeQ <- mkSizedFIFO(bufferCount); // bufidx
   Vector#(BufferCount, Reg#(Tuple2#(Bit#(8), Bit#(32)))) dmaWriteStatus <- replicateM(mkReg(tuple2(0,0))); // bufferidx -> tag, curoffset
   Vector#(BufferCount, Reg#(Bit#(8))) requestBufferIdx <- replicateM(mkReg(0)); // tag->bufferidx
   Vector#(BufferCount, Reg#(Bit#(32))) dmaWriteRefs <- replicateM(mkReg(0));
   Vector#(BufferCount, Reg#(Bit#(32))) dmaReadRefs <- replicateM(mkReg(0));

	rule flushRead;
		let q <- pageCache.readWord;
		let d = tpl_1(q);
		let t = tpl_2(q);

		let idx = requestBufferIdx[t];
		writeBuffer.enq(d,truncate(idx));
	endrule

	Reg#(Maybe#(Bit#(8))) curWriteBuf <- mkReg(tagged Invalid);
	Reg#(Bit#(5)) burstCount <- mkReg(0);
	Reg#(Bit#(32)) writeCount <- mkReg(0);


	FIFO#(Bit#(8)) startDmaFlushQ <- mkFIFO;
	rule startFlushDma ( burstCount == 0 && !isValid(curWriteBuf) );
		let rbuf <- writeBuffer.getReadyIdx;
		let rcount = writeBuffer.getDataCount(rbuf);
		//$display ( "datacount: %d", rcount );
		if ( rcount >= 4 ) begin
			curWriteBuf <= tagged Valid zeroExtend(rbuf);
			startDmaFlushQ.enq(zeroExtend(rbuf));
			
			/*
			let s = dmaWriteStatus[rbuf];
			let tag = tpl_1(s);
			let offset = tpl_2(s);
			dmaWriteStatus[rbuf] <= tuple2(tag,offset+(16*4));
			let wrRef = dmaWriteRefs[rbuf];
			burstCount <= 1;
		  
			//$display( "%d: starting burst %d", rbuf, offset );
			we.writeServers[0].request.put(MemengineCmd{pointer:wrRef, base:zeroExtend(offset), len:16*4, burstLen:16*4});
			*/
		end
		
	endrule
	rule startFlushDma2;
		let rbuf = startDmaFlushQ.first;
		startDmaFlushQ.deq;

		let s = dmaWriteStatus[rbuf];
		let tag = tpl_1(s);
		let offset = tpl_2(s);
		dmaWriteStatus[rbuf] <= tuple2(tag,offset+(16*4));
		let wrRef = dmaWriteRefs[rbuf];
		burstCount <= 1;
	  
		//$display( "%d: starting burst %d", rbuf, offset );
		we.writeServers[0].request.put(MemengineCmd{pointer:wrRef, base:zeroExtend(offset), len:16*4, burstLen:16*4});
	endrule

	FIFO#(Bit#(8)) curWriteBufQ <- mkSizedFIFO(5);
	rule flushDma ( burstCount > 0 && isValid(curWriteBuf));
		if ( burstCount >= 4 ) begin
			burstCount <= 0;
			curWriteBuf <= tagged Invalid;
		end else burstCount <= burstCount + 1;
		let rbuf = fromMaybe(0,curWriteBuf);
		
		writeBuffer.reqDeq(truncate(rbuf));
		curWriteBufQ.enq(rbuf);
		//$display( "%d: requesting burst data  %d %d", rbuf, burstCount, writeCount );
	endrule
	rule flushDma2;
		let rbuf = curWriteBufQ.first;
		curWriteBufQ.deq;
		let d <- writeBuffer.respDeq;
		
		let s = dmaWriteStatus[rbuf];
		let tag = tpl_1(s);
		let offset = tpl_2(s);

		we.dataPipes[0].enq(d);

		if ( writeCount + 1 >= fromInteger(pageWords) ) begin
			writeCount <= 0;
			indication.readDone(zeroExtend(rbuf));
			//dmaWriteStatus[rbuf] <= tuple2(tag,0);
			readBufferFreeQ.enq(rbuf);
		end else begin
			writeCount <= writeCount + 1;
		end
		//$display( "%d: writing burst data %d", rbuf, writeCount );
	endrule

	Reg#(Bit#(32)) dmaReadCount <- mkReg(0);
	Reg#(Bit#(5)) dmaReadBurstCount <- mkReg(0);

	FIFO#(Bit#(8)) readBurstIdxQ <- mkSizedFIFO(8);
	FIFO#(Bit#(8)) readIdxQ <- mkFIFO;

	rule driveHostDmaReq (dmaReadCount > 0);
		let bufIdx = readIdxQ.first;
		let rdRef = dmaReadRefs[bufIdx];
		let dmaReadOffset = fromInteger(pageBytes)-dmaReadCount;
		re.readServers[0].request.put(MemengineCmd{pointer:rdRef, base:extend(dmaReadOffset), len:(16*4), burstLen:(16*4)});
		dmaReadCount <= dmaReadCount - 16*4;
		if ( dmaReadCount == 16*4) readIdxQ.deq;

		readBurstIdxQ.enq(readIdxQ.first);
	endrule
	
	Reg#(Bit#(32)) pageWriteCount <- mkReg(0);
	rule flushHostRead;
		let bufidx = readBurstIdxQ.first;
		if ( dmaReadBurstCount >= 4-1 ) begin
			dmaReadBurstCount <= 0;
			readBurstIdxQ.deq;

			if ( pageWriteCount + 4 >= fromInteger(pageWords) ) begin
				pageWriteCount <= 0;
				indication.writeDone(zeroExtend(bufidx));
			end else begin
				pageWriteCount <= pageWriteCount + 4;
			end
		end else begin
			dmaReadBurstCount <= dmaReadBurstCount + 1;
		end

      let v <- toGet(re.dataPipes[0]).get;
	  pageCache.writeWord(v, bufidx);
	endrule

	FIFO#(FlashCmd) flashCmdQ <- mkSizedFIFO(32);
	rule driveFlashCmd;
		let cmd = flashCmdQ.first;

		if ( cmd.cmd == Read ) begin
			flashCmdQ.deq;
			let freeidx = readBufferFreeQ.first;
			readBufferFreeQ.deq;
			//Bit#(32) writeRef = dmaWriteRefs[freeidx];
			dmaWriteStatus[freeidx] <= tuple2(cmd.tag, 0);
			requestBufferIdx[cmd.tag] <= freeidx;

			pageCache.readPage( zeroExtend(cmd.page), cmd.tag);
			$display( "starting page read %d at tag %d in buffer %", cmd.page, cmd.tag, freeidx );
		end else if ( cmd.cmd == Write ) begin
			if ( dmaReadCount == 0 ) begin
				flashCmdQ.deq;
				dmaReadCount <= fromInteger(pageBytes);

				pageCache.writePage(zeroExtend(cmd.page), cmd.tag);
				readIdxQ.enq(cmd.tag);
			end
		end
	endrule

	//(* mutually_exclusive = "startFlushDma, driveFlashCmd" *)
   

   interface FlashRequest request;
	method Action readPage(Bit#(32) channel, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) tag);

		CmdType cmd = Read;
		FlashCmd fcmd = FlashCmd{
			channel: truncate(channel),
			chip: truncate(chip),
			block: truncate(block),
			page: truncate(page),
			cmd: cmd,
			tag: truncate(tag)};

		flashCmdQ.enq(fcmd);

			
	endmethod
   method Action writePage(Bit#(32) channel, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) tag);
		CmdType cmd = Write;
		FlashCmd fcmd = FlashCmd{
			channel: truncate(channel),
			chip: truncate(chip),
			block: truncate(block),
			page: truncate(page),
			cmd: cmd,
			tag: truncate(tag)};

		flashCmdQ.enq(fcmd);
	endmethod
	method Action erasePage(Bit#(32) channel, Bit#(32) chip, Bit#(32) block);
		CmdType cmd = Erase;
		FlashCmd fcmd = FlashCmd{
			channel: truncate(channel),
			chip: truncate(chip),
			block: truncate(block),
			page: 0,
			cmd: cmd,
			tag: 0};

		flashCmdQ.enq(fcmd);
	endmethod
	method Action sendTest(Bit#(32) data);
		auroraIntra1.send(zeroExtend({16'hc001, data[15:0]}), 7);
	endmethod
	method Action addWriteHostBuffer(Bit#(32) pointer, Bit#(32) idx);
		writeBufferFreeQ.enq(truncate(idx));
		dmaReadRefs[idx] <= truncate(pointer);
	endmethod
	method Action addReadHostBuffer(Bit#(32) pointer, Bit#(32) idx);
		readBufferFreeQ.enq(truncate(idx));
		dmaWriteRefs[idx] <= truncate(pointer);
	endmethod
   endinterface

   interface ObjectReadClient dmaReadClient = re.dmaClient;
   interface ObjectWriteClient dmaWriteClient = we.dmaClient;

   interface Aurora_Pins aurora_fmc1 = auroraIntra1.aurora;
   interface Aurora_Clock_Pins aurora_clk_fmc1 = gtx_clk_fmc1.aurora_clk;
endmodule
