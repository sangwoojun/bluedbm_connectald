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

import Vector::*;
import FIFOF::*;
import FIFO::*;
import Connectable::*;
import BRAMFIFO::*;

import PortalMemory::*;
import Dma::*;
import MemreadEngine::*;
import MemwriteEngine::*;

import PlatformInterfaces::*;
//import BlueDBMPlatform::*;

//////////////////////////////////////////////

typedef enum {Cmd_ReadPage, Cmd_WritePage, Cmd_EraseBlock} BlueDBMCmdType deriving (Bits, Eq);
typedef struct {
	Bit#(64) pageIdx; 
	BlueDBMCmdType cmd;
	Bit#(8) tag;
} BlueDBMCommand deriving (Bits, Eq);
interface FlashControllerIfc; //BlueDBM access flash
	method Action command(BlueDBMCommand cmd);
	method ActionValue#(Tuple2#(Bit#(64),Bit#(32))) readWord;
endinterface
interface BlueDBMHostIfc;
	method ActionValue#(BlueDBMCommand) getCommand;

	method Action writeBackPage(Bit#(8) tag); 
	method Action writeWord(Bit#(64) data, Bit#(32) tag);
	method Action readPage(Bit#(8) tag);
	method ActionValue#(Tuple2#(Bit#(64), Bit#(8))) readWord;
	
	method ActionValue#(Bit#(64)) getRawWord();
	method Action putRawWord(Bit#(64) word);
	method Bool started;

	interface PlatformIndication indication;
endinterface
///////////////////////////////////////////

interface InterfaceRequest;
	method Action setDmaHandle(Bit#(32) hostHandle);
	method Action readPage(Bit#(64) pageIdx, Bit#(32) tag);
	method Action writePage(Bit#(64) pageIdx, Bit#(32) tag);
	method Action readRawWord(Bit#(64) data);
endinterface

interface Interface;
	interface InterfaceRequest request;
	interface FlashControllerIfc flash;
	interface BlueDBMHostIfc host;
endinterface

interface InterfaceIndication;
   method Action pageReadDone(Bit#(32) tag);
   method Action pageWriteDone(Bit#(32) tag);
   method Action pageWriteFail(Bit#(32) tag);
   method Action hexdump(Bit#(32) a, Bit#(32) b);
   method Action writeRawWord(Bit#(64) data);
endinterface

module mkInterfaceRequest#(
			InterfaceIndication indication,
			PlatformIndication platformIndication,
			ObjectReadServer#(64) dma_read_server,
			ObjectWriteServer#(64) dma_write_server)(Interface);

	Integer pageSize = 8192;

	let readFifoBuf <- mkSizedBRAMFIFO(2048);
	let readFifo <- mkSizedFIFOF(256);
	rule relayreadfifo;
		readFifoBuf.enq(readFifo.first);
		readFifo.deq;
	endrule

	let writeFifo <- mkSizedFIFOF(128);

	MemreadEngine#(64) re <- mkMemreadEngine(1, readFifo);
	MemwriteEngine#(64) we <- mkMemwriteEngine(4, writeFifo);

	Reg#(ObjectPointer) hostDmaHandle <- mkReg(0);

	mkConnection(re.dmaClient,dma_read_server);
	mkConnection(we.dmaClient,dma_write_server);

   /*
   rule start(iterCnt > 0);
      re.start(rdPointer, 0, numWords*4, burstLen*4);
      we.start(wrPointer, 0, numWords*4, burstLen*4);
      iterCnt <= iterCnt-1;
   endrule

   rule finish;
      let rv0 <- re.finish;
      let rv1 <- we.finish;
      if(iterCnt==0)
	 indication.done;
   endrule
   
   rule xfer;
      //$display("xfer: %h", readFifo.first);
      readFifo.deq;
      writeFifo.enq(readFifo.first);
   endrule
   */
	Vector#(64, Reg#(Bit#(8))) bufferedWriteCount <- replicateM(mkReg(0)); // per tag
	//Vector#(64, FIFO#(Bool)) bufferedWriteToken <- replicateM(mkReg(0)); // per tag
	Vector#(64, FIFO#(Bit#(64))) writeBuffer <- replicateM(mkSizedFIFO(24));
	Vector#(64, Reg#(Bit#(ObjectOffsetSize))) writeBufferOffset <- replicateM(mkReg(0));

	Reg#(Bit#(8)) writeFlushCounter <- mkReg(0);
	Reg#(Bit#(8)) writeFlushTag <- mkReg(0);
	FIFO#(Bit#(8)) nextBurstQ <- mkSizedFIFO(8);
	rule startWriteFlush ( writeFlushCounter == 0 );
		let nextTag = nextBurstQ.first;
		nextBurstQ.deq;
		//bufferedWriteToken[nextTag].deq;
		writeFlushTag <= nextTag;
		writeFlushCounter <= 16;
		Bit#(ObjectOffsetSize) offset = writeBufferOffset[nextTag];
		Bit#(ObjectOffsetSize) absoffset = offset + fromInteger(pageSize)*extend(nextTag);
		//indication.hexdump(0,nextTag);
		
		we.start(hostDmaHandle, absoffset, 32*4, 32*4); //FIXME <- expecting 16 * 64bit bursts.
		if ( offset + 16*8 >= fromInteger(pageSize) ) begin
			writeBufferOffset[nextTag] <= 0;
			indication.pageReadDone(extend(nextTag));
		end
		else writeBufferOffset[nextTag] <= offset + 16*8;

	endrule
	rule driveWriteFlush( writeFlushCounter > 0);
		let tag = writeFlushTag;
		Bit#(64) data = writeBuffer[tag].first;
		writeBuffer[tag].deq;
		writeFlushCounter <= writeFlushCounter - 1;
		writeFifo.enq(data);
		//indication.hexdump(1,extend(writeFlushCounter));
	endrule
	rule finishWrite;
		let rv1 <- we.finish;
	endrule
	rule finishRead;
		let rv1 <- re.finish;
	endrule

	FIFO#(Bit#(64)) rawWordInQ <- mkSizedFIFO(32);

	FIFO#(BlueDBMCommand) bluedbmCommand <- mkSizedFIFO(64);
	FIFO#(Bit#(8)) writeTagQ <- mkSizedFIFO(64);
	Reg#(Bit#(32)) curWriteCount <- mkReg(0);
   
	interface InterfaceRequest request;
	method Action setDmaHandle(Bit#(32) hostHandle);
		hostDmaHandle <= hostHandle;
	endmethod
	method Action readPage(Bit#(64) pageIdx, Bit#(32) tag);
		bluedbmCommand.enq(BlueDBMCommand{pageIdx:pageIdx, cmd: Cmd_ReadPage, tag:truncate(tag)});
	endmethod
	method Action writePage(Bit#(64) pageIdx, Bit#(32) tag);
		if ( tag < 64 ) begin
			bluedbmCommand.enq(BlueDBMCommand{pageIdx:pageIdx, cmd: Cmd_WritePage, tag:truncate(tag)});
		end else begin
			indication.pageWriteFail(tag);
		end
	endmethod

	method Action readRawWord(Bit#(64) data);
		rawWordInQ.enq(data);
	endmethod
	endinterface
	
	interface FlashControllerIfc flash;
		method Action command(BlueDBMCommand cmd);
			if ( cmd.cmd == Cmd_ReadPage ) begin
				//readPageQ.enq(tuple2(cmd.pageIdx, cmd.tag));
			end
		endmethod
		method ActionValue#(Tuple2#(Bit#(64), Bit#(32))) readWord;
			//dmaReadQ.deq;
			//return dmaReadQ.first;
			return tuple2(0,0);
		endmethod
	endinterface

	interface BlueDBMHostIfc host;
	method ActionValue#(BlueDBMCommand) getCommand;
		bluedbmCommand.deq;
		return bluedbmCommand.first;
	endmethod
	method Action writeBackPage(Bit#(8) tag); 
		//writeBackPageQ.enq(tag); //Not needed because buffer is alr ready
	endmethod
	method Action writeWord(Bit#(64) data, Bit#(32) tag);
		//dmaWriteQ.enq(tuple2(data,tag));
		writeBuffer[tag].enq(data);
		if ( bufferedWriteCount[tag] + 1 >= 16 ) begin
			bufferedWriteCount[tag] <= 0;
			//bufferedWriteToken[tag].enq(True);
			nextBurstQ.enq(truncate(tag));
			//indication.hexdump(0,1);
		end else begin
			bufferedWriteCount[tag] <= bufferedWriteCount[tag] + 1;
		end
	endmethod
	method Action readPage(Bit#(8) tag);
		Bit#(ObjectOffsetSize) absoffset = fromInteger(pageSize)*extend(tag);
		if ( tag < 64 ) begin
			re.start(hostDmaHandle, absoffset, fromInteger(pageSize), 16*4);
			writeTagQ.enq(truncate(bluedbmCommand.first.tag));
		end else begin
			indication.hexdump(32'hdead, extend(tag));
		end
	endmethod
	method ActionValue#(Tuple2#(Bit#(64), Bit#(8))) readWord;
		readFifoBuf.deq;
		let tag = writeTagQ.first;
		if ( curWriteCount + 1 >= fromInteger(pageSize)/8 ) begin
			writeTagQ.deq;
			curWriteCount <= 0;
			indication.pageWriteDone(extend(tag));
		end else begin
			curWriteCount <= curWriteCount +1;
		end
		return tuple2(readFifoBuf.first, extend(tag));
	endmethod
	
	method ActionValue#(Bit#(64)) getRawWord();
		rawWordInQ.deq;
		return rawWordInQ.first;
	endmethod
	method Action putRawWord(Bit#(64) word) if ( hostDmaHandle > 0 );
		indication.writeRawWord(word);
		//indication.hexdump(word[63:32], word[31:0]);
	endmethod

	method Bool started;
		let ret = False;
		if ( hostDmaHandle > 0 ) ret = True; //TODO replace with proper start request
		
		return ret;
	endmethod

	interface PlatformIndication indication = platformIndication;
	endinterface
endmodule
