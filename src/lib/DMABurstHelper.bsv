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

typedef 4 NumDmaChannels;

typedef TAdd#(8192,64) PageBytes;
typedef 16 WordBytes;
typedef 128 WriteBufferCount;
typedef 64 WriteTagCount;
typedef 64 ReadBufferCount;
/*
typedef 64 WriteBufferCount;
typedef 64 WriteTagCount;
typedef 64 ReadBufferCount;
*/
typedef TLog#(ReadBufferCount) ReadBufferCountLog;
typedef TLog#(WriteBufferCount) WriteBufferCountLog;
typedef TLog#(WriteTagCount) WriteTagCountLog;

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
	
	Integer wordBytes = valueOf(WordBytes); 
	Integer burstBytes = 16*4;
	Integer burstWords = burstBytes/wordBytes;
	
	Integer pageWords = pageBytes/wordBytes;
	
	Vector#(ReadBufferCount, Reg#(Tuple2#(Bit#(32),Bit#(32)))) dmaReadRefs <- replicateM(mkReg(?));
	
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
		method ActionValue#(Tuple2#(Bit#(8),Bit#(8))) done;
		method ActionValue#(Bit#(8)) getDmaRefReq;
		method Action dmaRefResp(Bit#(32) bref, Bit#(32) off);
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
	
	Integer bufferCount = valueOf(WriteBufferCount);
	Integer tagCount = valueOf(WriteTagCount);
	Integer wordBytes = valueOf(WordBytes); 
	Integer burstBytes = 16*4;
	Integer burstWords = burstBytes/wordBytes;
	
	Integer pageBytes = valueOf(PageBytes);

	BRAMFIFOVectorIfc#(WriteTagCountLog, 12, Bit#(wordSz)) writeBuffer <- mkBRAMFIFOVector(4);
	Vector#(WriteTagCount, Reg#(Tuple2#(Bit#(32), Bit#(4)))) dmaWriteOffset <- replicateM(mkReg(tuple2(0,0))); // tag -> curoffset, writePhaseIdx
	Vector#(WriteTagCount, Reg#(Bit#(4))) dmaWriteOffsetNew <- replicateM(mkReg(0)); // tag -> writePhaseIdx
	Vector#(WriteTagCount, Reg#(Bit#(8))) dmaWriteBuf <- replicateM(mkReg(0)); // tag -> bufferidx
   
	//Reg#(Bit#(32)) writeCount <- mkReg(0);

	FIFO#(Bit#(32)) dmaBurstOffsetQ <- mkFIFO;
	FIFO#(Tuple2#(Bit#(8), Bit#(8))) dmaWriteLocQ <- mkSizedFIFO(16);

	FIFO#(Bit#(8)) dmaRefReqQ <- mkFIFO; // idx
	FIFO#(Tuple2#(Bit#(32),Bit#(32))) dmaRefRespQ <- mkFIFO; // dmaref, offset

	FIFO#(Bit#(8)) startWriteTagQ <- mkFIFO;
	FIFO#(Bit#(8)) startDmaFlushQ <- mkFIFO;
	rule startFlushDma;
		let tag <- writeBuffer.getReadyIdx;
		let rcount = writeBuffer.getDataCount(tag);

/*
		totalDmaCount[rbuf] <= totalDmaCount[rbuf]+1;
		$display ( "starting burst to buf %d -> %d", rbuf,
			totalDmaCount[rbuf]);
*/
		if ( rcount >= fromInteger(burstWords) ) begin
			startDmaFlushQ.enq(zeroExtend(tag));
			let rbuf = dmaWriteBuf[tag];
			dmaRefReqQ.enq(rbuf);
		end
	endrule
	FIFO#(MemengineCmd) engineCmdQ <- mkSizedFIFO(4);
	rule startFlushDma2;
		let tag = startDmaFlushQ.first;
		startDmaFlushQ.deq;

		let doff = dmaWriteOffset[tag];
		let offset = tpl_1(doff);
		let phase = tpl_2(doff);
		let nphase = dmaWriteOffsetNew[tag];
		if ( phase != nphase ) begin
			offset = 0;
			phase = nphase;
		end

		let rbuf = dmaWriteBuf[tag];
		dmaWriteOffset[tag] <= tuple2(offset+fromInteger(burstBytes), phase);

		//let wr = dmaWriteRefs[rbuf];
		let wr = dmaRefRespQ.first;
		dmaRefRespQ.deq;
		let wrRef = tpl_1(wr);
		let wrOff = tpl_2(wr);
		let burstOff = wrOff + offset;
	  
		if ( offset < fromInteger(pageBytes) ) begin
			//$display( "%d: starting burst %d", rbuf, offset );
			wServer.request.put(MemengineCmd{pointer:wrRef, base:zeroExtend(burstOff), len:fromInteger(burstBytes), burstLen:fromInteger(burstBytes)});

			dmaWriteLocQ.enq(tuple2(rbuf, tag));
			dmaBurstOffsetQ.enq(offset);
			startWriteTagQ.enq(tag);
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

	FIFO#(Bit#(8)) curWriteTagQ <- mkSizedFIFO(5);
	Reg#(Bit#(5)) burstCount <- mkReg(0);
	rule flushDma;
		if ( burstCount+1 >= fromInteger(burstWords) ) begin
			burstCount <= 0;
			startWriteTagQ.deq;
		end else burstCount <= burstCount + 1;
		let tag = startWriteTagQ.first;

		writeBuffer.reqDeq(truncate(tag));
		curWriteTagQ.enq(tag);
		//$display( "%d: requesting burst data  %d %d", rbuf, burstCount, writeCount );
	endrule

	FIFO#(Bit#(32)) writeCountQ <- mkFIFO;
	FIFO#(Tuple2#(Bit#(8), Bit#(8))) writeDoneQ <- mkFIFO;

	rule flushDma2;
		let tag = curWriteTagQ.first;
		curWriteTagQ.deq;

		let d <- writeBuffer.respDeq;

		wPipe.enq(d);

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
		writeBuffer.enq(word,truncate(tag));
	endmethod
	method Action startWrite(Bit#(8) tag, Bit#(8) freeidx, Bit#(32) wordCount);
		//dmaWriteStatus[freeidx] <= tuple2(tag, 0);
		dmaWriteBuf[tag] <= freeidx;
		dmaWriteOffsetNew[tag] <= dmaWriteOffsetNew[tag] + 1;
		
		writeCountQ.enq(wordCount);
	endmethod

	interface FreeBufferClientIfc bufClient;
		method ActionValue#(Tuple2#(Bit#(8),Bit#(8))) done;
			writeDoneQ.deq;
			return writeDoneQ.first;
		endmethod
		method ActionValue#(Bit#(8)) getDmaRefReq;
			dmaRefReqQ.deq;
			return dmaRefReqQ.first;
		endmethod
		method Action dmaRefResp(Bit#(32) bref, Bit#(32) off);
			dmaRefRespQ.enq(tuple2(bref,off));
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
	
	Integer bufferCount = valueOf(WriteBufferCount);
	Integer numClient = valueOf(tNumClient);
   
	Vector#(WriteBufferCount, Reg#(Tuple2#(Bit#(32),Bit#(32)))) dmaWriteRefs <- replicateM(mkReg(?)); //bufferidx -> dmaref,offset
	
	Reg#(Bit#(8)) addBufferIdx <- mkReg(0);
	FIFO#(Bit#(8)) writeBufferFreeQ <- mkSizedFIFO(bufferCount); // bufidx

	FIFOF#(Tuple2#(Bit#(8), Bit#(8))) writeDoneQ <- mkFIFOF;
	for ( Integer i = 0; i < numClient; i = i + 1) begin
		FIFOF#(Tuple2#(Bit#(8), Bit#(8))) writeDoneQ1 <- mkFIFOF;
		rule checkDone1;
			let done1 <- clients[i].done;
			writeDoneQ.enq(done1);
		endrule
	
	
		rule getDmaRef;
			let idx <- clients[i].getDmaRefReq;

			let wr = dmaWriteRefs[idx];
			let wrRef = tpl_1(wr);
			let wrOff = tpl_2(wr);
			clients[i].dmaRefResp(wrRef, wrOff);
		endrule
	end

/*
	FIFOF#(Tuple2#(Bit#(8), Bit#(8))) writeDoneQ2 <- mkFIFOF;
	
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
*/	
	method Action addBuffer(Bit#(32) offset, Bit#(32) bref);
		addBufferIdx <= addBufferIdx + 1;
		writeBufferFreeQ.enq(addBufferIdx);
		dmaWriteRefs[addBufferIdx] <= tuple2(bref, offset);
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
