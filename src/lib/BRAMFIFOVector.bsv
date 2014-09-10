
/*
Note:
The semantics of this FIFO implementation is somewhat different from normal FIFOs.
(1) enq may fire even when it is full. In which case the request will be queued.
(2) deqReq may fire when FIFO is empty. This will also be queued until there is data.
*/

import BRAM::*;
import FIFO::*;
import FIFOF::*;
import Vector::*;

interface BRAMFIFOVectorIfc#(numeric type vlog, numeric type fifosize, type fifotype);
	method Action enq(fifotype data, Bit#(vlog) idx);
	method Action reqDeq(Bit#(vlog) idx);
	method ActionValue#(fifotype) respDeq;
	method Bit#(11) getDataCount(Bit#(vlog) idx);
	method ActionValue#(Bit#(vlog)) getReadyIdx;
endinterface

module mkBRAMFIFOVector#(Integer thresh) (BRAMFIFOVectorIfc#(vlog, fifosize, fifotype))
	provisos (
		Literal#(fifotype), 
		Bits#(fifotype, fifotypesz),
		Add#(a__, 11, TAdd#(vlog, TLog#(fifosize)))
		);
	
	BRAM2Port#(Bit#(TAdd#(vlog,TLog#(fifosize))), fifotype) fifoBuffer <- mkBRAM2Server(defaultValue); 

	Vector#(TExp#(vlog), Reg#(Bit#(11))) headpointer <- replicateM(mkReg(0));
	Vector#(TExp#(vlog), Reg#(Bit#(11))) tailpointer <- replicateM(mkReg(0));
	function Bool  isEmpty(Bit#(vlog) idx);
		Bool res = False;
		if ( headpointer[idx] == tailpointer[idx] ) res = True;

		return res;
	endfunction
	function Bool isFull(Bit#(vlog) idx);
		Bool res = False;
		Integer bufsize = valueOf(fifosize);
		let head1 = headpointer[idx]+1;
		if ( head1 >= fromInteger(bufsize) ) head1 = 0;

		if ( head1 == tailpointer[idx] ) res = True;
		return res;
	endfunction

	function Bit#(11) dataCount(Bit#(vlog) idx);
		let head = headpointer[idx];
		let tail = tailpointer[idx];
		if ( head < tail ) head = head + fromInteger(valueOf(fifosize));
		let diff = head - tail;

		return diff;
	endfunction

	FIFO#(Bool) fakeQ0 <- mkFIFO;
	FIFO#(Bool) fakeQ1 <- mkFIFO;
	FIFO#(Bool) fakeQ2 <- mkFIFO;
	
	Vector#(TExp#(vlog), Reg#(Maybe#(fifotype))) deqV <- replicateM(mkReg(tagged Invalid));

/*
	FIFO#(Bit#(vlog)) reqs <- mkFIFO;
	rule relayDeqV;
		let v <- fifoBuffer.portB.response.get();
		let idx = reqs.first;
		reqs.deq;
		//if ( idx > 0 ) $display ( "%d relaying", idx );

		if ( datacount[idx] > 0 ) begin
			deqV[idx] <= tagged Valid v;
		end
	endrule
*/
	FIFO#(Bit#(vlog)) readyIdxQ <- mkSizedFIFO(32);

	FIFO#(Tuple2#(fifotype, Bit#(vlog))) enqQ <- mkSizedFIFO(1);
	FIFO#(Bit#(vlog)) deqQ <- mkSizedFIFO(1);

	rule applyenq;
		let cmdd = enqQ.first;
		let idx = tpl_2(cmdd);
		let data = tpl_1(cmdd);
		Integer bufsize = valueOf(fifosize);
		if ( !isFull( idx ) ) begin
			enqQ.deq;
			let head1 = headpointer[idx]+1;
			if ( head1 >= fromInteger(bufsize) ) head1 = 0;
			headpointer[idx] <= head1;

			//$display ("%d enqing to head %d %d %d", idx, head1, tailpointer[idx], datacount[idx]+1);

			fifoBuffer.portA.request.put(BRAMRequest{write:True, responseOnWrite:False, address:zeroExtend(idx)*fromInteger(bufsize)+zeroExtend(headpointer[idx]), datain:data});

			if ( dataCount(idx) + 1 >= fromInteger(thresh) ) begin
				readyIdxQ.enq(idx);
			end
		end
		else fakeQ2.deq;
	endrule
	rule applydeq;
		let idx = deqQ.first;

		Integer bufsize = valueOf(fifosize);
		if ( !isEmpty(idx) ) begin
			deqQ.deq;
			let tail1 = tailpointer[idx]+1;
			if ( tail1 >= fromInteger(bufsize) ) tail1 = 0;
			tailpointer[idx] <= tail1;

			fifoBuffer.portA.request.put(
				BRAMRequest{
				write:False, 
				responseOnWrite:?, 
				address:zeroExtend(idx)*fromInteger(bufsize)+zeroExtend(tailpointer[idx]), 
				datain:?});
		end
		else fakeQ2.deq;
	endrule
	
	method Action enq(fifotype data, Bit#(vlog) idx); 
		if (isFull ( idx )) fakeQ0.deq;
		enqQ.enq(tuple2(data,idx));
	/*

		Integer bufsize = valueOf(fifosize);
		let head1 = headpointer[idx]+1;
		if ( head1 >= fromInteger(bufsize) ) head1 = 0;
		headpointer[idx] <= head1;

		//$display ("%d enqing to head %d %d %d", idx, head1, tailpointer[idx], datacount[idx]+1);

		fifoBuffer.portA.request.put(BRAMRequest{write:True, responseOnWrite:False, address:zeroExtend(idx)*fromInteger(bufsize)+zeroExtend(headpointer[idx]), datain:data});

		if ( dataCount(idx) + 1 >= fromInteger(thresh) ) begin
			readyIdxQ.enq(idx);
		end
*/
	endmethod
	
	method Bit#(11) getDataCount(Bit#(vlog) idx);
		return dataCount(idx);
	endmethod

	method Action reqDeq(Bit#(vlog) idx);
		if ( isEmpty( idx ) ) fakeQ1.deq;
		deqQ.enq(idx);
		/*

		Integer bufsize = valueOf(fifosize);
		let tail1 = tailpointer[idx]+1;
		if ( tail1 >= fromInteger(bufsize) ) tail1 = 0;
		tailpointer[idx] <= tail1;

		fifoBuffer.portA.request.put(
			BRAMRequest{
			write:False, 
			responseOnWrite:?, 
			address:zeroExtend(idx)*fromInteger(bufsize)+zeroExtend(tailpointer[idx]), 
			datain:?});
		*/
	endmethod
	method ActionValue#(fifotype) respDeq;
		let v <- fifoBuffer.portA.response.get();
		return v;
	endmethod

	method ActionValue#(Bit#(vlog)) getReadyIdx;
		readyIdxQ.deq;
		return readyIdxQ.first;
	endmethod
endmodule
