import ClientServer::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import Vector::*;
import PortalMemory::*;
import MemTypes::*;
import MemreadEngine::*;
import MemwriteEngine::*;
import Pipe::*;

import BRAMFIFOVector::*;


typedef TAdd#(8192,64) PageBytes;
typedef 16 WordBytes;
typedef 128 BufferCount;
typedef TLog#(BufferCount) BufferCountLog;

interface DMAReadEngineIfc#(numeric type wordSz);
	method ActionValue#(Tuple2#(Bit#(wordSz), Bit#(8))) read;
	method Action startRead(Bit#(8) bufidx, Bit#(32) wordCount);
	method ActionValue#(Bit#(8)) done;
	method Action addBuffer(Bit#(8) idx, Bit#(32) offset, Bit#(32) bref);
endinterface
module mkDmaReadEngine#(
	Server#(MemengineCmd,Bool) rServer,
	PipeOut#(Bit#(wordSz)) rPipe )(DMAReadEngineIfc#(wordSz))
	;
	
	Integer pageBytes = valueOf(PageBytes);
	
	Integer bufferCount = valueOf(BufferCount);
	Integer wordBytes = valueOf(WordBytes); 
	Integer burstBytes = 16*4;
	Integer burstWords = burstBytes/wordBytes;
	
	Integer pageWords = pageBytes/wordBytes;
	
	Vector#(BufferCount, Reg#(Tuple2#(Bit#(32),Bit#(32)))) dmaReadRefs <- replicateM(mkReg(?));
	
	Reg#(Bit#(32)) dmaReadCount <- mkReg(0);

	FIFO#(Tuple2#(Bit#(8),Bit#(8))) readBurstIdxQ <- mkSizedFIFO(8);
	FIFO#(Bit#(8)) readIdxQ <- mkFIFO;

	rule read_finish;
		let rv0 <- rServer.response.get;
	endrule

	rule driveHostDmaReq (dmaReadCount > 0);
		let bufIdx = readIdxQ.first;
		let rd = dmaReadRefs[bufIdx];
		let rdRef = tpl_1(rd);
		let rdOff = tpl_2(rd);
		let dmaReadOffset = rdOff+fromInteger(pageBytes)-dmaReadCount;


		rServer.request.put(MemengineCmd{pointer:rdRef, base:extend(dmaReadOffset), len:fromInteger(burstBytes), burstLen:fromInteger(burstBytes)});


		if ( dmaReadCount > fromInteger(burstBytes) ) begin
			dmaReadCount <= dmaReadCount - fromInteger(burstBytes);
			readBurstIdxQ.enq(tuple2(readIdxQ.first, 
				fromInteger(burstWords)));
		end else begin
			dmaReadCount <= 0;
			readIdxQ.deq;
			readBurstIdxQ.enq(tuple2(readIdxQ.first, 
				truncate(dmaReadCount/fromInteger(wordBytes))));
		end

	endrule

	FIFO#(Tuple2#(Bit#(wordSz), Bit#(8))) readQ <- mkSizedFIFO(8);
	
	Reg#(Bit#(8)) dmaReadBurstCount <- mkReg(0);
	FIFO#(Bit#(8)) readDoneQ <- mkFIFO;
	Reg#(Bit#(32)) pageWriteCount <- mkReg(0);
	rule flushHostRead;
		let ri = readBurstIdxQ.first;
		let bufidx = tpl_1(ri);
		let burstr = tpl_2(ri);
		if ( dmaReadBurstCount >= fromInteger(burstWords)-1 ) begin
			dmaReadBurstCount <= 0;
			readBurstIdxQ.deq;

			if ( pageWriteCount + fromInteger(burstWords) >= fromInteger(pageWords) ) begin
				pageWriteCount <= 0;
				//indication.writeDone(zeroExtend(bufidx));
				readDoneQ.enq(bufidx);
			end else begin
				pageWriteCount <= pageWriteCount + fromInteger(burstWords);
			end
		end else begin
			dmaReadBurstCount <= dmaReadBurstCount + 1;
		end

      let v <- toGet(rPipe).get;
	  if ( dmaReadBurstCount < burstr ) readQ.enq(tuple2(v, bufidx));
	endrule
	
	method ActionValue#(Tuple2#(Bit#(wordSz), Bit#(8))) read;
		readQ.deq;
		return readQ.first;
	endmethod
	method Action startRead(Bit#(8) bufidx, Bit#(32) wordCount) if ( dmaReadCount == 0 );
			dmaReadCount <= wordCount*fromInteger(wordBytes);
			readIdxQ.enq(bufidx);
	endmethod
	method ActionValue#(Bit#(8)) done;
		readDoneQ.deq;
		return readDoneQ.first;
	endmethod
	method Action addBuffer(Bit#(8) idx, Bit#(32) offset, Bit#(32) bref);
		dmaReadRefs[idx] <= tuple2(bref, offset);
	endmethod
endmodule
	


interface FreeBufferClientIfc;
		method Action addBuffer(Bit#(8) idx, Bit#(32) offset, Bit#(32) bref);
		method ActionValue#(Tuple2#(Bit#(8),Bit#(8))) done;
endinterface

interface DMAWriteEngineIfc#(numeric type wordSz);
	method Action write(Bit#(wordSz) word, Bit#(8) tag); 
	method Action startWrite(Bit#(8) tag, Bit#(8) freeidx, Bit#(32) wordCount);
	interface FreeBufferClientIfc bufClient;
endinterface
module mkDmaWriteEngine# (
	Server#(MemengineCmd,Bool) wServer,
	PipeIn#(Bit#(wordSz)) wPipe )(DMAWriteEngineIfc#(wordSz))
	;
	
	Integer bufferCount = valueOf(BufferCount);
	Integer wordBytes = valueOf(WordBytes); 
	Integer burstBytes = 16*4;
	Integer burstWords = burstBytes/wordBytes;
	
	Integer pageBytes = valueOf(PageBytes);


	BRAMFIFOVectorIfc#(BufferCountLog, 12, Bit#(wordSz)) writeBuffer <- mkBRAMFIFOVector(4);
	Vector#(BufferCount, Reg#(Tuple2#(Bit#(8), Bit#(32)))) dmaWriteStatus <- replicateM(mkReg(tuple2(0,0))); // bufferidx -> tag, curoffset
	Vector#(BufferCount, Reg#(Bit#(8))) requestBufferIdx <- replicateM(mkReg(0)); // tag->bufferidx
   Vector#(BufferCount, Reg#(Tuple2#(Bit#(32),Bit#(32)))) dmaWriteRefs <- replicateM(mkReg(?));
   

	//Vector#(BufferCount, Reg#(Bit#(32))) totalDmaCount <- replicateM(mkReg(0));

	//Reg#(Bit#(32)) writeCount <- mkReg(0);

	FIFO#(Bit#(32)) dmaBurstOffsetQ <- mkFIFO;
	FIFO#(Tuple2#(Bit#(8), Bit#(8))) dmaWriteLocQ <- mkFIFO;

	FIFO#(Bit#(8)) startWriteBufQ <- mkFIFO;
	FIFO#(Bit#(8)) startDmaFlushQ <- mkFIFO;
	rule startFlushDma;
		let rbuf <- writeBuffer.getReadyIdx;
		let rcount = writeBuffer.getDataCount(rbuf);

/*
		totalDmaCount[rbuf] <= totalDmaCount[rbuf]+1;
		$display ( "starting burst to buf %d -> %d", rbuf,
			totalDmaCount[rbuf]);
*/
		if ( rcount >= fromInteger(burstWords) ) begin
			startDmaFlushQ.enq(zeroExtend(rbuf));
		end
	endrule
	FIFO#(MemengineCmd) engineCmdQ <- mkSizedFIFO(4);
	rule startFlushDma2;
		let rbuf = startDmaFlushQ.first;
		startDmaFlushQ.deq;

		let s = dmaWriteStatus[rbuf];
		let tag = tpl_1(s);
		let offset = tpl_2(s);
		dmaWriteStatus[rbuf] <= tuple2(tag,offset+fromInteger(burstBytes));
		let wr = dmaWriteRefs[rbuf];
		let wrRef = tpl_1(wr);
		let wrOff = tpl_2(wr);

		let burstOff = wrOff + offset;
	  
		if ( offset < fromInteger(pageBytes) ) begin
			//$display( "%d: starting burst %d", rbuf, offset );
			wServer.request.put(MemengineCmd{pointer:wrRef, base:zeroExtend(burstOff), len:fromInteger(burstBytes), burstLen:fromInteger(burstBytes)});

			dmaWriteLocQ.enq(tuple2(rbuf, tag));
			dmaBurstOffsetQ.enq(offset);
			startWriteBufQ.enq(zeroExtend(rbuf));
		end
		//engineCmdQ.enq(MemengineCmd{pointer:wrRef, base:zeroExtend(burstOff), len:fromInteger(burstBytes), burstLen:fromInteger(burstBytes)});
	endrule
	/*
	rule driveEngineCmd;
		let cmd = engineCmdQ.first;
		engineCmdQ.deq;
		wServer.request.put(cmd);
	endrule
	*/

	FIFO#(Bit#(8)) curWriteBufQ <- mkSizedFIFO(5);
	Reg#(Bit#(5)) burstCount <- mkReg(0);
	rule flushDma;
		if ( burstCount+1 >= fromInteger(burstWords) ) begin
			burstCount <= 0;
			startWriteBufQ.deq;
		end else burstCount <= burstCount + 1;
		let rbuf = startWriteBufQ.first;

		writeBuffer.reqDeq(truncate(rbuf));
		curWriteBufQ.enq(rbuf);
		//$display( "%d: requesting burst data  %d %d", rbuf, burstCount, writeCount );
	endrule

	FIFO#(Bit#(32)) writeCountQ <- mkFIFO;
	FIFO#(Tuple2#(Bit#(8), Bit#(8))) writeDoneQ <- mkFIFO;

	rule flushDma2;
		let rbuf = curWriteBufQ.first;
		curWriteBufQ.deq;
		let d <- writeBuffer.respDeq;
		
		let s = dmaWriteStatus[rbuf];
		let tag = tpl_1(s);
		let offset = tpl_2(s);

		wPipe.enq(d);

/*
		if ( writeCount + 1 >= writeCountQ.first ) begin
			writeCount <= 0;
			writeDoneQ.enq(tuple2(rbuf, tag));
			writeCountQ.deq;
		end else begin
			writeCount <= writeCount + 1;
		end
*/
		//$display( "%d: writing burst data %d", rbuf, writeCount );
	endrule

	rule write_finish;
		dmaBurstOffsetQ.deq;
		dmaWriteLocQ.deq;

		let rv1 <- wServer.response.get;
		let dmaOff = dmaBurstOffsetQ.first;
		let bd = dmaWriteLocQ.first;
		let rbuf = tpl_1(bd);
		let tag = tpl_2(bd);
		

		let wReqBytes = writeCountQ.first * fromInteger(wordBytes);
		let nextOff = dmaOff + fromInteger(burstBytes);

		if ( nextOff >= wReqBytes ) begin
			writeDoneQ.enq(tuple2(rbuf, tag));
			writeCountQ.deq;
		end
	endrule

	method Action write(Bit#(wordSz) word, Bit#(8) tag); 
		let idx = requestBufferIdx[tag];
		writeBuffer.enq(word,truncate(idx));
	endmethod
	method Action startWrite(Bit#(8) tag, Bit#(8) freeidx, Bit#(32) wordCount);
		dmaWriteStatus[freeidx] <= tuple2(tag, 0);
		
		requestBufferIdx[tag] <= freeidx;

		writeCountQ.enq(wordCount);
	endmethod

	interface FreeBufferClientIfc bufClient;
		method Action addBuffer(Bit#(8) idx, Bit#(32) offset, Bit#(32) bref);
			dmaWriteRefs[idx] <= tuple2(bref, offset);
		endmethod
		method ActionValue#(Tuple2#(Bit#(8),Bit#(8))) done;
			writeDoneQ.deq;
			return writeDoneQ.first;
		endmethod
	endinterface
endmodule

interface FreeBufferManagerIfc;
	method Action addBuffer(Bit#(32) offset, Bit#(32) bref);
	method Action returnFreeBuf(Bit#(8) idx);
	method ActionValue#(Bit#(8)) getFreeBufIdx;
	method ActionValue#(Tuple2#(Bit#(8),Bit#(8))) done;
endinterface
module mkFreeBufferManager#(Vector#(tNumClient, FreeBufferClientIfc) clients) (FreeBufferManagerIfc);
	
	Integer bufferCount = valueOf(BufferCount);
	Integer numClient = valueOf(tNumClient);
	
	Reg#(Bit#(8)) addBufferIdx <- mkReg(0);
	FIFO#(Bit#(8)) writeBufferFreeQ <- mkSizedFIFO(bufferCount); // bufidx

	FIFOF#(Tuple2#(Bit#(8), Bit#(8))) writeDoneQ1 <- mkFIFOF;
	FIFOF#(Tuple2#(Bit#(8), Bit#(8))) writeDoneQ2 <- mkFIFOF;
	FIFOF#(Tuple2#(Bit#(8), Bit#(8))) writeDoneQ <- mkFIFOF;
	
	rule checkDone1;
		let done1 <- clients[0].done;
		writeDoneQ1.enq(done1);
	endrule
	rule checkDone2;
		let done2 <- clients[1].done;
		writeDoneQ2.enq(done2);
	endrule
	rule collectDone;
		if ( writeDoneQ1.notEmpty ) begin
			writeDoneQ.enq(writeDoneQ1.first);
			writeDoneQ1.deq;
		end else if 
		( writeDoneQ2.notEmpty ) begin
			writeDoneQ.enq(writeDoneQ2.first);
			writeDoneQ2.deq;
		end
	endrule
	
	method Action addBuffer(Bit#(32) offset, Bit#(32) bref);
		addBufferIdx <= addBufferIdx + 1;
		writeBufferFreeQ.enq(addBufferIdx);
		for (Integer i = 0; i < numClient; i = i + 1 ) begin
			clients[i].addBuffer(addBufferIdx, offset, bref);
		end
	endmethod

	method ActionValue#(Bit#(8)) getFreeBufIdx;
		writeBufferFreeQ.deq;
		return writeBufferFreeQ.first;
	endmethod
	
	method Action returnFreeBuf(Bit#(8) idx);
		writeBufferFreeQ.enq(idx);
	endmethod
	method ActionValue#(Tuple2#(Bit#(8),Bit#(8))) done;
			writeDoneQ.deq;
			return writeDoneQ.first;
	endmethod
endmodule
