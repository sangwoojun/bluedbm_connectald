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

//typedef TAdd#(8192,64) PageBytes;
typedef TAdd#(8192,128) PageBytes;
typedef 16 WordBytes;
typedef 32 WriteBufferCount;
typedef TMul#(WriteBufferCount, NumDmaChannels) WriteBufferTotal;
//typedef 32 WriteTagCount;
typedef 64 ReadBufferCount;
typedef TMul#(ReadBufferCount, NumDmaChannels) ReadBufferTotal;

typedef TLog#(ReadBufferCount) ReadBufferCountLog;
typedef TLog#(WriteBufferCount) WriteBufferCountLog;
//typedef TLog#(WriteTagCount) WriteTagCountLog;

interface DMAReadEngineIfc#(numeric type wordSz);
	method ActionValue#(Tuple2#(Bit#(wordSz), Bit#(8))) read;
	method Action startRead(Bit#(8) bufidx, Bit#(32) wordCount);
	method ActionValue#(Bit#(8)) done;
	method Action addBuffer(Bit#(8) idx, Bit#(32) offset, Bit#(32) bref);
endinterface
module mkDmaReadEngine#(
	Server#(MemengineCmd,Bool) rServer,
	PipeOut#(Bit#(wordSz)) rPipe)(DMAReadEngineIfc#(wordSz))
	;
	
	Integer pageBytes = valueOf(PageBytes);
	
	Integer wordBytes = valueOf(WordBytes); 
	Integer burstBytes = 16*8;
	Integer burstWords = burstBytes/wordBytes;
	
	Vector#(ReadBufferCount, Reg#(Tuple2#(Bit#(32),Bit#(32)))) dmaReadRefs <- replicateM(mkReg(?));
	
	Reg#(Bit#(32)) dmaReadCount <- mkReg(0);

	FIFO#(Tuple2#(Bit#(8),Bit#(8))) readBurstIdxQ <- mkSizedFIFO(8);
	FIFO#(Bit#(8)) readIdxQ <- mkFIFO;
	
	FIFO#(Bit#(8)) readDoneQ <- mkFIFO;

	FIFO#(Maybe#(Bit#(8))) pageDoneQ <- mkSizedFIFO(8);

	rule driveHostDmaReq (dmaReadCount > 0);
		let bufIdx = readIdxQ.first;
		let rd = dmaReadRefs[bufIdx];
		let rdRef = tpl_1(rd);
		let rdOff = tpl_2(rd);
		let dmaReadOffset = rdOff+fromInteger(pageBytes)-dmaReadCount;

		rServer.request.put(MemengineCmd{sglId:rdRef, base:extend(dmaReadOffset), len:fromInteger(burstBytes), burstLen:fromInteger(burstBytes)});


		if ( dmaReadCount > fromInteger(burstBytes) ) begin
			dmaReadCount <= dmaReadCount - fromInteger(burstBytes);
			readBurstIdxQ.enq(tuple2(readIdxQ.first, 
				fromInteger(burstWords)));

			pageDoneQ.enq(tagged Invalid);
		end else begin
			dmaReadCount <= 0;
			readIdxQ.deq;

			readBurstIdxQ.enq(tuple2(readIdxQ.first, 
				truncate(dmaReadCount/fromInteger(wordBytes))));
			
			pageDoneQ.enq(tagged Valid bufIdx);
		end

	endrule

	FIFO#(Tuple2#(Bit#(wordSz), Bit#(8))) readQ <- mkSizedFIFO(8);
	
	Reg#(Bit#(8)) dmaReadBurstCount <- mkReg(0);
	//Reg#(Bit#(32)) pageWriteCount <- mkReg(0);
	rule flushHostRead;
		let ri = readBurstIdxQ.first;
		let bufidx = tpl_1(ri);
		let burstr = tpl_2(ri);
		if ( dmaReadBurstCount >= fromInteger(burstWords)-1 ) begin
			dmaReadBurstCount <= 0;
			readBurstIdxQ.deq;

		end else begin
			dmaReadBurstCount <= dmaReadBurstCount + 1;
		end

      let v <- toGet(rPipe).get;

	  if ( dmaReadBurstCount < burstr ) readQ.enq(tuple2(v, bufidx));
	endrule
	
	rule read_finish;
		let rv0 <- rServer.response.get;
		let isdone = pageDoneQ.first;
		pageDoneQ.deq;

		if ( isValid(isdone) ) begin
			let bufidx = fromMaybe(0,isdone);
			readDoneQ.enq(bufidx);
		end
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
		method ActionValue#(Bit#(8)) done;
		method ActionValue#(Bit#(8)) getDmaRefReq;
		method Action dmaRefResp(Bit#(32) bref, Bit#(16) off);
endinterface

interface DMAWriteEngineIfc#(numeric type wordSz);
	method Action write(Bit#(wordSz) word, Bit#(8) tag); 
	method Action startWrite(Bit#(8) freeidx, Bit#(16) wordCount);
	interface FreeBufferClientIfc bufClient;
endinterface
module mkDmaWriteEngine# (
	Server#(MemengineCmd,Bool) wServer,
	PipeIn#(Bit#(wordSz)) wPipe )(DMAWriteEngineIfc#(wordSz))
	;
	
	Integer bufferCount = valueOf(WriteBufferCount);
	Integer wordBytes = valueOf(WordBytes); 
	Integer burstBytes = 32*4;
	Integer burstWords = burstBytes/wordBytes;
	
	Integer pageBytes = valueOf(PageBytes);

	BRAMFIFOVectorIfc#(WriteBufferCountLog, 12, Bit#(wordSz)) writeBuffer <- mkBRAMFIFOVector(8);
	Vector#(WriteBufferCount, Reg#(Tuple2#(Bit#(16), Bit#(4)))) dmaWriteOffset <- replicateM(mkReg(tuple2(0,0))); // tag -> curoffset, writeEpochIdx
	Vector#(WriteBufferCount, Reg#(Bit#(4))) dmaWriteOffsetNew <- replicateM(mkReg(0)); // tag -> writeEpochIdx
	Vector#(WriteBufferCount, Reg#(Tuple2#(Bit#(8),Bit#(16)))) dmaWriteBuf <- replicateM(mkReg(tuple2(0,0))); // tag -> bufferidx, writeCount
   
	//Reg#(Bit#(32)) writeCount <- mkReg(0);

	FIFO#(Bit#(16)) dmaBurstOffsetQ <- mkSizedFIFO(16);
	FIFO#(Tuple2#(Bit#(8), Bit#(8))) dmaWriteLocQ <- mkSizedFIFO(16);

	FIFO#(Bit#(8)) dmaRefReqQ <- mkFIFO; // idx
	FIFO#(Tuple2#(Bit#(32),Bit#(16))) dmaRefRespQ <- mkFIFO; // dmaref, offset


	FIFO#(Bit#(8)) startWriteTagQ <- mkSizedFIFO(8);
	FIFO#(Bit#(8)) startDmaFlushQ <- mkSizedFIFO(8);
	rule startFlushDma;
		let tag <- writeBuffer.getReadyIdx;
		let rcount = writeBuffer.getDataCount(tag);

		if ( rcount >= fromInteger(burstWords) ) begin
			startDmaFlushQ.enq(zeroExtend(tag));
			let rbuf = tpl_1(dmaWriteBuf[tag]);
			dmaRefReqQ.enq(rbuf);

			writeBuffer.startBurst(fromInteger(burstWords), tag);
			//$display( "Start burst at tag %d", tag );
		end
	endrule
	/*
	FIFO#(Bit#(8)) startWriteTestQ <- mkSizedFIFO(8);
	Reg#(Bit#(16)) curTestWriteOff <- mkReg(0);
	rule startFlushDma;
		let tag = startWriteTestQ.first;
		let wcount = tpl_2(dmaWriteBuf[tag]);
		if ( curTestWriteOff < wcount/fromInteger(burstWords) ) begin
			curTestWriteOff <= curTestWriteOff + 1;
		end else begin
			startWriteTestQ.deq;
			curTestWriteOff <= 0;

		end

		startDmaFlushQ.enq(zeroExtend(tag));
		let rbuf = tpl_1(dmaWriteBuf[tag]);
		dmaRefReqQ.enq(rbuf);
	endrule
	*/

	//Reg#(Bit#(16)) dummyOffset <- mkReg(0);

	FIFO#(MemengineCmd) engineCmdQ <- mkSizedFIFO(4);
	rule startFlushDma2;
		let tag = startDmaFlushQ.first;
		startDmaFlushQ.deq;

		let doff = dmaWriteOffset[tag];
		let offset = tpl_1(doff);
		//let offset = dummyOffset;
		let phase = tpl_2(doff);
		let nphase = dmaWriteOffsetNew[tag];
		if ( phase != nphase ) begin
			offset = 0;
			phase = nphase;
		end

		let rbuf = tpl_1(dmaWriteBuf[tag]);
		dmaWriteOffset[tag] <= tuple2(offset+fromInteger(burstBytes), phase);

		//let wr = dmaWriteRefs[rbuf];
		let wr = dmaRefRespQ.first;
		dmaRefRespQ.deq;
		let wrRef = tpl_1(wr);
		let wrOff = tpl_2(wr);
		let burstOff = wrOff + offset;
	  
		if ( offset < fromInteger(pageBytes) ) begin
			engineCmdQ.enq(MemengineCmd{sglId:wrRef, base:zeroExtend(burstOff), len:fromInteger(burstBytes), burstLen:fromInteger(burstBytes)});

			dmaWriteLocQ.enq(tuple2(rbuf, tag));
			dmaBurstOffsetQ.enq(offset);
			startWriteTagQ.enq(tag);

			//$display( "Sending burst cmd tag %d offset %d", tag, offset );
		end else begin
			$display( "EXCEPTION: Offset out of range %x", offset );
		end

/*
		if ( dummyOffset+fromInteger(burstBytes) < fromInteger(pageBytes) ) begin
			dummyOffset <= offset + fromInteger(burstBytes);
		end else dummyOffset <= 0;
*/
	endrule

	rule driveEngineCmd;
		let cmd = engineCmdQ.first;
		engineCmdQ.deq;
		wServer.request.put(cmd);
	endrule

	FIFO#(Bit#(8)) curWriteTagQ <- mkSizedFIFO(8);
	Reg#(Bit#(5)) burstCount <- mkReg(0);
	rule flushDma;
		if ( burstCount+1 >= fromInteger(burstWords) ) begin
			burstCount <= 0;
			startWriteTagQ.deq;
		end else burstCount <= burstCount + 1;
		let tag = startWriteTagQ.first;

		writeBuffer.reqDeq(truncate(tag));
		curWriteTagQ.enq(tag);
		//$display ( "requesting data at tag %d", tag );
	endrule

	FIFO#(Tuple2#(Bit#(8), Bit#(8))) writeDoneQ <- mkFIFO;

	rule flushDma2;
		let tag = curWriteTagQ.first;
		curWriteTagQ.deq;


		let d <- writeBuffer.respDeq;
		//$display ( "enqing data at tag %d %x", tag , d );

		wPipe.enq(d);
	endrule

	rule write_finish;
		dmaBurstOffsetQ.deq;
		dmaWriteLocQ.deq;

		let rv1 <- wServer.response.get;
		let dmaOff = dmaBurstOffsetQ.first;
		let bd = dmaWriteLocQ.first;
		let rbuf = tpl_1(bd);
		let tag = tpl_2(bd);
		
		let wReqBytes = tpl_2(dmaWriteBuf[tag]) * fromInteger(wordBytes);
		let nextOff = dmaOff + fromInteger(burstBytes);
		//$display( "burst for off %d tag %d done (%d/%d)", dmaOff, tag, nextOff, wReqBytes );

		if ( nextOff >= wReqBytes ) begin
			writeDoneQ.enq(tuple2(rbuf, tag));
			//$display( "Sending write done at tag %d", tag );
			//writeCountQ.deq;
		end
	endrule

	FIFO#(Bit#(8)) freeInternalTagQ <- mkSizedFIFO(bufferCount);
	Vector#(WriteBufferCount, Reg#(Bit#(8))) internalTagMap <- replicateM(mkReg(0)); // internal tag -> external tag
	Vector#(128, Reg#(Bit#(8))) externalTagMap <- replicateM(mkReg(0)); // external tag -> internal tag //FIXME

	Reg#(Bit#(8)) freeInternalTagCounter <- mkReg(0);
	rule fillFreeITag (freeInternalTagCounter < fromInteger(bufferCount));
		freeInternalTagCounter <= freeInternalTagCounter + 1;
		freeInternalTagQ.enq(freeInternalTagCounter);
	endrule
	//TODO set "started" or something once this init is done

	method Action write(Bit#(wordSz) word, Bit#(8) bufidx); 
		let tag = externalTagMap[bufidx];
		writeBuffer.enq(word,truncate(tag));
		//$display ( "DMA writing %x to %d", word, bufidx );
	endmethod
	method Action startWrite(Bit#(8) freeidx, Bit#(16) wordCount);
		
		freeInternalTagQ.deq;
		let tag = freeInternalTagQ.first;

		//todo store buffer -> tag in shared buffer

		//internalTagMap[tag] <= etag;
		//externalTagMap[etag] <= tag;
		externalTagMap[freeidx] <= tag;

		dmaWriteBuf[tag] <= tuple2(freeidx, wordCount);
		dmaWriteOffsetNew[tag] <= dmaWriteOffsetNew[tag] + 1;

		//$display( "Starting writing %d -> %d", etag, tag );

		//startWriteTestQ.enq(tag);
	endmethod

	interface FreeBufferClientIfc bufClient;
		method ActionValue#(Bit#(8)) done;
			let dr = writeDoneQ.first;
			let tag = tpl_2(dr);
			freeInternalTagQ.enq(tag);

			writeDoneQ.deq;

			return tpl_1(dr);
		endmethod
		method ActionValue#(Bit#(8)) getDmaRefReq;
			dmaRefReqQ.deq;
			return dmaRefReqQ.first;
		endmethod
		method Action dmaRefResp(Bit#(32) bref, Bit#(16) off);
			dmaRefRespQ.enq(tuple2(bref,off));
		endmethod
	endinterface
endmodule

interface FreeBufferManagerIfc;
	method Action addBuffer(Bit#(16) offset, Bit#(32) bref);
	method ActionValue#(Bit#(8)) done;
endinterface
module mkFreeBufferManager#(Vector#(tNumClient, FreeBufferClientIfc) clients) (FreeBufferManagerIfc);
	
	Integer bufferCount = valueOf(WriteBufferCount);
	Integer bufferCountLog = valueOf(WriteBufferCountLog);
	Integer numClient = valueOf(tNumClient);
   
	Vector#(WriteBufferTotal, Reg#(Tuple2#(Bit#(32),Bit#(16)))) dmaWriteRefs <- replicateM(mkReg(?)); //bufferidx -> dmaref,offset
	
	Reg#(Bit#(8)) addBufferIdx <- mkReg(0);


	FIFOF#(Bit#(8)) writeDoneQ <- mkFIFOF;
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

	method Action addBuffer(Bit#(16) offset, Bit#(32) bref);
		addBufferIdx <= addBufferIdx + 1;
		dmaWriteRefs[addBufferIdx] <= tuple2(bref, offset);
	endmethod

	method ActionValue#(Bit#(8)) done;
			writeDoneQ.deq;
			return writeDoneQ.first;
	endmethod
endmodule
