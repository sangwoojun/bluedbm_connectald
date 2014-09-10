package Reducer;
import PlatformInterfaces::*;
import MRTypes::*;

import FIFO::*;

module mkReducer (ReducerIfc);
	FIFO#(ReducerContext) tfQ <- mkFIFO();
	FIFO#(ReduceHeader) rhQ <- mkFIFO();
	method Action putKV(ReduceHeader header, ReducerContext ctx);
		tfQ.enq(ctx);
		rhQ.enq(header);
	endmethod
	
	method ActionValue#(Tuple2#(ReducerResult, ReducerContext)) getResult;
		tfQ.deq;
		rhQ.deq;
		ReducerResult rr = unpack(0);
		rr.key = rhQ.first.key;
		ReducerContext ct = tfQ.first;
		ct.count = ct.count + 1;
		//if ( ct.count > 2 ) rr.valid = True;
		rr.valid = False;
		return tuple2(rr, ct);
	endmethod
endmodule

module mkFinalReducer#(PlatformIndication indication) (FinalizerIfc);
	FIFO#(ReducerContext) ctxQ <- mkFIFO();
	method Action putCtx(ReducerContext ctx);
		if ( ctx.count > 1 ) indication.sendKey(ctx.key);
	endmethod
endmodule
endpackage: Reducer
