import FIFO::*;
import BRAMFIFO::*;
import Clocks::*;
import Vector::*;

import PlatformInterfaces::*;
import Interface::*;

import DRAMController::*;
//import PageCache::*;

import Mapper::*;
import Reducer::*;
import MRTypes::*;

interface BlueDBMPlatformIfc;
//	method Action readPage(Bit#(64) pageIdx);
	interface PlatformRequest request;
endinterface

typedef 128 InQSize;
typedef 64 WordSize;
typedef 1 MapperCount;
typedef 2 ReducerCount;
typedef 8 ReducerBufferCnt;

typedef TAdd#(1, TDiv#(ReducerContextSz, 512)) ReducerContextC;

module mkBlueDBMPlatform#(
	//FlashControllerIfc flash, 
	BlueDBMHostIfc host, 
	DRAMControllerIfc dram/*,
	Vector#(AuroraPorts, AuroraIfc) auroras, 
	Vector#(AuroraIntraPorts, AuroraIfc32) auroraIntras, 
	Vector#(I2C_Count, I2C_User) i2cs*/
	) (BlueDBMPlatformIfc)
	
	provisos(
		Bits#(MapHeader, MapHeaderSz)
		//,Add#(tsmin,64, MapHeaderSz)
		)
	;
	
	PlatformIndication indication = host.indication;

	FIFO#(Bool) platformStartQ <- mkFIFO();
	Reg#(Bool) platformStarted <- mkReg(False);
	rule platformStart;
		platformStarted <= True;
		platformStartQ.deq;
	endrule

	Reg#(Bit#(64)) totalMapReq <- mkReg(0);
	Reg#(Bool) isFinalize <- mkReg(False);

	/////////////// Mapper Ingestion
	Reg#(Bit#(32)) curInIn <- mkReg(0);
	Reg#(Bit#(32)) curInRequested <- mkReg(0);

	FIFO#(MapHeader) mapHeaderQ <- mkSizedBRAMFIFO(valueOf(InQSize));
	Reg#(MapHeader) mapHeaderBuf <- mkReg(unpack(0));
	Reg#(Bit#(8)) mapHeader8Idx <- mkReg(0);
	Reg#(Bit#(8)) mapHeader4Idx <- mkReg(0);

	rule sendInReq ( curInRequested < 4 && curInIn < 4 && 
			fromInteger(valueOf(InQSize)) > curInIn + curInRequested ) ;
		Bit#(32) reqCount = 8;//fromInteger(valueOf(InQSize))/2 + 2;
		indication.requestWords(reqCount);
		curInRequested <= curInRequested + reqCount;
	endrule
	
	Vector#(MapperCount, MapperIfc) mappers <- replicateM(mkMapper);
	rule feedMapper;
		mappers[0].putKV(mapHeaderQ.first);
		mapHeaderQ.deq;
		curInIn <= curInIn - 1;
	endrule

	Vector#(ReducerCount, FIFO#(ReduceHeader)) reduceQs <- replicateM(mkSizedFIFO(8));
	Vector#(ReducerCount, FIFO#(Tuple2#(Bit#(64),ReducerContext))) reduceCtxQs <- replicateM(mkSizedFIFO(8));

	Reg#(Maybe#(Bit#(64))) ctxReadKey <- mkReg(tagged Invalid);
	Reg#(Bit#(64)) ctxReadOffset <- mkReg(0);
	Reg#(Bit#(64)) invalidMapCnt <- mkReg(0);
	rule relayReducer(!isValid(ctxReadKey));
		ReduceHeader rh <- mappers[0].getKV;
		if ( rh.valid ) begin
			reduceQs[0].enq(rh);
		end
		else begin
			invalidMapCnt <= invalidMapCnt + 1;
		end

		ctxReadKey <= tagged Valid rh.key;
		ctxReadOffset <= 0;
	endrule

	
	FIFO#(Bit#(64)) ctxReqIdxQ <- mkSizedFIFO(1);
	rule reqCtxRead(!isFinalize && isValid(ctxReadKey)); //TODO if ctxReadKey is already asked, wait
		Bit#(64) reqKey = fromMaybe(0, ctxReadKey);
		dram.readReq((reqKey+ctxReadOffset)<<6, 64);
		ctxReadOffset <= ctxReadOffset + 1;
		ctxReqIdxQ.enq(reqKey+ctxReadOffset);
	endrule


	FIFO#(Bool) reduceThrottleQ <- mkSizedFIFO(1);

	Vector#(7,Reg#(Bit#(64))) ctxDirtyBuf <- replicateM(mkReg(0));
	FIFO#(Bit#(TSub#(512,64))) ctxDirtyQ <- mkFIFO();
	Reg#(Bit#(8)) ctxDirtyIdx <- mkReg(0);

	Reg#(Bit#(64)) lastCtxHead <- mkReg(0);
	Reg#(Bool) ctxHeadSearching <- mkReg(False);

	rule recvCtxHead ( !isFinalize && ctxHeadSearching );
		ctxReqIdxQ.deq;
		Bit#(64) ctxReqIdx = ctxReqIdxQ.first;

		let data <- dram.read;
		Bit#(8) magic = data[7:0];//ctx.magic;
		//$display("%h, %h\n", data, magic);
		let d = ctxDirtyQ.first;
		if ( magic != 8'hfe && magic != 8'hfd ) begin
			//$display ( "%h@@!!!\n", ctxReqIdx );
			ctxDirtyQ.deq;

			dram.write(ctxReqIdx<<6, {0,
				d,
				8'hfd}, 64);
			ctxHeadSearching <= False;
			lastCtxHead <= ctxReqIdx;
			ctxReadKey <= tagged Invalid;
			ctxReadOffset <= 0;
		end
	endrule

	rule recvCtxRead ( !isFinalize && !ctxHeadSearching );
		ctxReqIdxQ.deq;
		Bit#(64) ctxReqIdx = ctxReqIdxQ.first;

		let data <- dram.read;
		ReducerContext ctx = unpack(truncate(data>>8));
		Bit#(8) magic = data[7:0];//ctx.magic;
		Bit#(64) key = ctx.key;
		Bit#(64) reqKey = fromMaybe(0, ctxReadKey);
		//$display ( "%h %h@@\n", key, magic );
		if ( magic == 8'hfe && key == reqKey) begin
			reduceCtxQs[0].enq(tuple2(ctxReqIdx,
				ctx));
			ctxReadKey <= tagged Invalid;
			ctxReadOffset <= 0;

			reduceThrottleQ.enq(True);
			
			//$display("%h-- %h %h\n", ctxReqIdx, ctx.magic, ctx.key);
		end else if ( magic != 8'hfe && magic!= 8'hfd ) begin
			ReducerContext rcn = unpack(0);
			//rcn.magic = 8'hfe;
			rcn.key = reqKey;
			reduceCtxQs[0].enq(tuple2(ctxReqIdx,rcn));
			
			reduceThrottleQ.enq(True);
		
			if ( ctxDirtyIdx + 1 >= 7 ) begin
				ctxReadKey <= tagged Valid (lastCtxHead+1);
				ctxReadOffset <= 0;
				ctxHeadSearching <= True;
				ctxDirtyQ.enq({
					ctxDirtyBuf[0],
					ctxDirtyBuf[1],
					ctxDirtyBuf[2],
					ctxDirtyBuf[3],
					ctxDirtyBuf[4],
					ctxDirtyBuf[5],
					ctxDirtyBuf[6]});
				ctxDirtyIdx <= 0;
			end else begin
				ctxDirtyBuf[ctxDirtyIdx] <= ctxReqIdx;
				ctxDirtyIdx <= ctxDirtyIdx + 1;
			
				ctxReadKey <= tagged Invalid;
				ctxReadOffset <= 0;
			end
			

			//$display("%h++ %h\n", ctxReqIdx, rcn.magic);
		end else begin
			//$display( "xx %h %h\n", key, ctxReqIdx );
		end

	endrule
	Vector#(ReducerCount, ReducerIfc) reducers <- replicateM(mkReducer);
	Vector#(ReducerCount, FIFO#(Bit#(64))) reduceCtxOffsetQs <- replicateM(mkSizedFIFO(4));
	rule feedReducer;
		reduceQs[0].deq;
		ReduceHeader rh = reduceQs[0].first;

		reduceCtxQs[0].deq;
		ReducerContext rc = tpl_2(reduceCtxQs[0].first);
		reduceCtxOffsetQs[0].enq(tpl_1(reduceCtxQs[0].first));

		reducers[0].putKV(rh, rc);
	endrule

	Reg#(Bit#(64)) totalReduceCnt <- mkReg(0);

	rule getReducerResult;
		let rr <- reducers[0].getResult;
		ReducerResult rr1 = tpl_1(rr);
		ReducerContext rr2 = tpl_2(rr);
		reduceThrottleQ.deq;

		Bit#(64) ctxoffset = reduceCtxOffsetQs[0].first;
		reduceCtxOffsetQs[0].deq;
		dram.write(ctxoffset<<6, {zeroExtend(pack(rr2)), 8'hfe}, 64);

		//$display("%h %hqqq\n", rr2.key, rr2.magic);
		if ( rr1.valid ) begin
			indication.rawWordTest(rr1.key);
		end

		totalReduceCnt <= totalReduceCnt + 1;
	endrule

	FIFO#(Bit#(32)) finalizeQ <- mkFIFO();
	rule finalizeD (totalMapReq <= invalidMapCnt + totalReduceCnt );
		finalizeQ.deq;
		isFinalize <= True;

	endrule

	Reg#(Maybe#(Bit#(TSub#(512,64)))) ctxFinalBuf <- mkReg(tagged Invalid);
	Reg#(Bit#(64)) ctxSweepIdx <- mkReg(0);
	FIFO#(Bool) finalizerThrottleQ <- mkSizedFIFO(1);
	Reg#(Bit#(8)) finalStage <- mkReg(0);
	rule finaliceR (isFinalize 
		&& ctxSweepIdx <= lastCtxHead 
		&& !isValid(ctxFinalBuf)
		&& finalStage == 0);

		ctxSweepIdx <= ctxSweepIdx + 1;
		dram.readReq((ctxSweepIdx)<<6, 64);
		finalizerThrottleQ.enq(True);
		finalStage <= 0;
	endrule
	Reg#(Bit#(8)) finalBufIdx <- mkReg(0);
	rule finalizeC (isFinalize && finalStage == 0);
		let d <- dram.read;
		Bit#(8) magic = d[7:0];
		if ( magic == 8'hfd ) begin
			ctxFinalBuf <= tagged Valid truncate(d>>8);
		end
		finalizerThrottleQ.deq;
	endrule

	FIFO#(Bool) finalizerSecondThrottleQ <- mkSizedFIFO(1);
	rule finalSecond(isFinalize && isValid(ctxFinalBuf));
		let d = fromMaybe(0, ctxFinalBuf);

		finalizerSecondThrottleQ.enq(True);
		Bit#(64) second = d[63:0];
		dram.readReq((second)<<6, 64);
		//$display ( "%h<-\n", second );
		finalStage <= 1;
		if ( finalBufIdx + 1 < 7 ) begin
			finalBufIdx <= finalBufIdx + 1;
			ctxFinalBuf <= tagged Valid (d>>64);
			if(  ctxSweepIdx <= lastCtxHead  ) begin
				indication.mrDone(0);
			end
		end else begin
			finalBufIdx <= 0;
			ctxFinalBuf <= tagged Invalid;
		end
	endrule

	FinalizerIfc finalizer <- mkFinalReducer(indication);

	rule finalSecondR(isFinalize && finalStage == 1);
		finalizerSecondThrottleQ.deq;
		//$display( "@@@\n" );
		finalStage <= 0;

		let d <- dram.read;
		Bit#(8) magic = d[7:0];
		if ( magic == 8'hfe ) begin
			ReducerContext ctx = unpack(truncate(d>>8));
			finalizer.putCtx(ctx);
		end
	endrule


	interface PlatformRequest request;
		method Action sendKey(Bit#(64) key);
			let mh = mapHeaderBuf;
			mh.key = key;
			mapHeaderQ.enq(mh);
			mapHeader4Idx <= 0;
			mapHeader8Idx <= 0;
			totalMapReq <= totalMapReq + 1;
			if ( curInRequested > 0 ) begin
				curInRequested <= curInRequested - 1;
			end
			curInIn <= curInIn + 1;
		endmethod
		method Action sendWord4(Bit#(32) data);
			mapHeaderBuf.value4[mapHeader4Idx] <= data;
			mapHeader4Idx <= mapHeader4Idx + 1;
		endmethod
		method Action sendWord8(Bit#(64) data);
			mapHeaderBuf.value8[mapHeader8Idx] <= data;
			mapHeader8Idx <= mapHeader8Idx + 1;
		endmethod
		method Action finalize(Bit#(32) dummy);
			ctxDirtyQ.enq({
				ctxDirtyBuf[0],
				ctxDirtyBuf[1],
				ctxDirtyBuf[2],
				ctxDirtyBuf[3],
				ctxDirtyBuf[4],
				ctxDirtyBuf[5],
				ctxDirtyBuf[6]});
			//FIXME stuff are still buffered in ctxDirtyBuf
			finalizeQ.enq(dummy);
		endmethod


		method Action start(Bit#(32) dummy);
			platformStartQ.enq(True);
		endmethod
		method Action rawWordRequest(Bit#(WordSize) data);
		endmethod

	endinterface
endmodule
