
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
	method Bit#(TAdd#(1,TLog#(fifosize))) getDataCount(Bit#(vlog) idx);
	method ActionValue#(Bit#(vlog)) getReadyIdx;
	method Action startBurst(Bit#(TAdd#(1,TLog#(fifosize))) burstCount, Bit#(vlog) idx);
endinterface

module mkBRAMFIFOVector#(Integer thresh) (BRAMFIFOVectorIfc#(vlog, fifosize, fifotype))
	provisos (
		Literal#(fifotype), 
		Bits#(fifotype, fifotypesz)
		//,
		//Add#(a__, 11, TAdd#(vlog, TLog#(fifosize)))
		);
	
	Integer fifoSize = valueOf(fifosize);

	Vector#(TExp#(vlog), Reg#(Bit#(TAdd#(1,TLog#(fifosize))))) enqTotal <- replicateM(mkReg(0));
	Vector#(TExp#(vlog), Reg#(Bit#(TAdd#(1,TLog#(fifosize))))) deqTotal <- replicateM(mkReg(0)); //including all eventual deqs when burst starts
	//Vector#(TExp#(vlog), Reg#(Bit#(TAdd#(1,TLog#(fifosize))))) deqCurrent <- replicateM(mkReg(0));


	BRAM2Port#(Bit#(TAdd#(vlog,TAdd#(1,TLog#(fifosize)))), fifotype) fifoBuffer <- mkBRAM2Server(defaultValue); 

	Vector#(TExp#(vlog), Reg#(Bit#(TAdd#(1,TLog#(fifosize))))) headpointer <- replicateM(mkReg(0));
	Vector#(TExp#(vlog), Reg#(Bit#(TAdd#(1,TLog#(fifosize))))) tailpointer <- replicateM(mkReg(0));
	/*
	function Bool isEmpty(Bit#(vlog) idx);
		Bool res = False;
		if ( enqTotal[idx] == deqCurrent[idx] ) res = True;

		//if ( headpointer[idx] == tailpointer[idx] ) res = True;

		return res;
	endfunction
	*/
	function Bool isFull(Bit#(vlog) idx);
		Bool res = False;

/*
		if ( enqTotal[idx] - deqCurrent[idx] >= fromInteger(fifoSize) )
			res = True;
			*/


		Integer bufsize = valueOf(fifosize);
		let head1 = headpointer[idx]+1;
		if ( head1 >= fromInteger(bufsize) ) head1 = 0;

		if ( head1 == tailpointer[idx] ) res = True;

		return res;
	endfunction

	function Bit#(TAdd#(1,TLog#(fifosize))) dataCount(Bit#(vlog) idx);
		let enqt = enqTotal[idx];
		let deqt = deqTotal[idx];
		let diff = enqt - deqt;

/*
		let head = headpointer[idx];
		let tail = tailpointer[idx];
		if ( head < tail ) head = head + fromInteger(valueOf(fifosize));
		let diff = head - tail;
 */

		return diff;
	endfunction

	FIFO#(Bool) fakeQ0 <- mkFIFO;
	FIFO#(Bool) fakeQ1 <- mkFIFO;
	
	FIFO#(Bit#(vlog)) readyIdxQ <- mkSizedFIFO(32);

	FIFO#(Tuple2#(fifotype, Bit#(vlog))) enqQ <- mkSizedFIFO(1);
	FIFO#(Tuple2#(fifotype, Bit#(vlog))) enqQd <- mkSizedFIFO(1);
	FIFO#(Bit#(vlog)) deqQ <- mkSizedFIFO(4);
	FIFOF#(Bit#(vlog)) deqQd <- mkSizedFIFOF(1);

	rule applyenq ( !isFull(tpl_2(enqQ.first)) );
		enqQ.deq;
		let cmdd = enqQ.first;
		let idx = tpl_2(cmdd);
		let data = tpl_1(cmdd);
		
		let head1 = headpointer[idx]+1;
		if ( head1 >= fromInteger(fifoSize) ) head1 = 0;
		headpointer[idx] <= head1;

		fifoBuffer.portB.request.put(BRAMRequest{write:True, responseOnWrite:False, address:zeroExtend(idx)*fromInteger(fifoSize)+zeroExtend(headpointer[idx]), datain:data});

	endrule
	rule applydeq (headpointer[deqQ.first] != tailpointer[deqQ.first] );
		let idx = deqQ.first;
		deqQ.deq;

		let tail1 = tailpointer[idx]+1;
		if ( tail1 >= fromInteger(fifoSize) ) tail1 = 0;
		tailpointer[idx] <= tail1;

		fifoBuffer.portA.request.put(
			BRAMRequest{
			write:False, 
			responseOnWrite:?, 
			address:zeroExtend(idx)*fromInteger(fifoSize)+zeroExtend(tailpointer[idx]), 
			datain:?});
	endrule


	method Action enq(fifotype data, Bit#(vlog) idx); 

		enqQ.enq(tuple2(data,idx));
		enqTotal[idx] <= enqTotal[idx] + 1;
		
		if ( dataCount(idx)+1 >= fromInteger(thresh) ) begin
			readyIdxQ.enq(idx);
		end
	endmethod
	
	method Bit#(TAdd#(1,TLog#(fifosize))) getDataCount(Bit#(vlog) idx);
		return dataCount(idx);
	endmethod

	method Action reqDeq(Bit#(vlog) idx);
		//if ( isEmpty( idx ) ) fakeQ1.deq;
		
		//deqCurrent[idx] <= deqCurrent[idx] + 1;
		deqQ.enq(idx);
	endmethod

	method ActionValue#(fifotype) respDeq;
		let v <- fifoBuffer.portA.response.get();
		return v;
	endmethod

	method ActionValue#(Bit#(vlog)) getReadyIdx;
		readyIdxQ.deq;
		return readyIdxQ.first;
	endmethod
	method Action startBurst(Bit#(TAdd#(1,TLog#(fifosize))) burstCount, Bit#(vlog) idx);
		deqTotal[idx] <= deqTotal[idx] + burstCount;
	endmethod
endmodule
