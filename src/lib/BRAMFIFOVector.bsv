
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
	method ActionValue#(Tuple2#(Bit#(vlog), Bit#(32))) getReadyIdx;
endinterface


module mkBRAMFIFOVector#(Integer thresh, Integer burstsPerIdx, Integer padBursts) (BRAMFIFOVectorIfc#(vlog, fifosize, fifotype))
	provisos (
	//	Literal#(fifotype), 
		Bits#(fifotype, fifotypesz)
		);
	
	Integer fifoSize = valueOf(fifosize);
	Integer numReadys = (burstsPerIdx + padBursts) / thresh;

	Vector#(TExp#(vlog), Reg#(Bit#(32))) enqTotal <- replicateM(mkReg(0));
	Reg#(Bit#(16)) padCnt <- mkReg(0);
	Reg#(Bit#(vlog)) padIdx <- mkReg(0);
	Reg#(fifotype) padData <- mkRegU();
	//including all eventual deqs when burst starts
	//Vector#(TExp#(vlog), Reg#(Bit#(32))) deqTotal <- replicateM(mkReg(0)); 
	Vector#(TExp#(vlog), Reg#(Bit#(32))) enqCnt <- replicateM(mkReg(0)); 
	Vector#(TExp#(vlog), Reg#(Bit#(32))) rdyCnt <- replicateM(mkReg(0)); 
	Vector#(TExp#(vlog), Reg#(Bit#(TAdd#(1,TLog#(fifosize))))) deqCnt <- replicateM(mkReg(0)); 
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
		let head1 = headpointer[idx]+1;
		if ( head1 >= fromInteger(fifoSize) ) head1 = 0;
		if ( head1 == tailpointer[idx] ) res = True;
		return res;
	endfunction

	//function Bit#(TAdd#(1,TLog#(fifosize))) dataCount(Bit#(vlog) idx);
	//	let enqt = enqTotal[idx];
	//	let deqt = deqTotal[idx];
	//	let diff = enqt - deqt;
	//	return diff;
	//endfunction

	//FIFO#(Bool) fakeQ0 <- mkFIFO;
	//FIFO#(Bool) fakeQ1 <- mkFIFO;
	
	FIFO#(Tuple2#(Bit#(vlog), Bit#(32))) readyIdxQ <- mkSizedFIFO(valueOf(TExp#(vlog)));

	//FIFO#(Tuple2#(fifotype, Bit#(vlog))) enqQ <- mkSizedFIFO(1);
	FIFO#(fifotype) enqQ <- mkFIFO();
	FIFO#(Bit#(vlog)) enqIdxQ <- mkFIFO();
	FIFO#(fifotype) enqInQ <- mkFIFO();
	FIFO#(Bit#(vlog)) enqInIdxQ <- mkFIFO();
	FIFO#(Bit#(vlog)) deqQ <- mkSizedFIFO(16);



	rule processEnq if (padCnt==0);
		let data = enqInQ.first;
		let idx = enqInIdxQ.first;
		enqInQ.deq;
		enqInIdxQ.deq;
		enqQ.enq(data);
		enqIdxQ.enq(idx);
		if (enqTotal[idx] == fromInteger(burstsPerIdx-1)) begin
			padCnt <= fromInteger(padBursts);
			padIdx <= idx;
			padData <= data;
			enqTotal[idx] <= 0;
		end
		else begin
			enqTotal[idx] <= enqTotal[idx] + 1;
		end
	endrule

	rule applyPad if (padCnt>0);
		enqQ.enq(padData); 
		enqIdxQ.enq(padIdx); 
		padCnt <= padCnt - 1;
	endrule

	rule applyenq;
		let data = enqQ.first;
		let idx = enqIdxQ.first;
		if ( !isFull( idx ) ) begin
			enqQ.deq;
			enqIdxQ.deq;
			let head1 = headpointer[idx]+1;
			if ( head1 >= fromInteger(fifoSize) ) head1 = 0;
			headpointer[idx] <= head1;

			fifoBuffer.portB.request.put(BRAMRequest{write:True, responseOnWrite:False, address:zeroExtend(idx)*fromInteger(fifoSize)+zeroExtend(headpointer[idx]), datain:data});
			//send a ready message every threshold bursts
			if (enqCnt[idx] == fromInteger(thresh-1)) begin
				readyIdxQ.enq(tuple2(idx, rdyCnt[idx]));
				if (rdyCnt[idx] >= fromInteger(numReadys - 1)) begin
					rdyCnt[idx] <= 0;
				end
				else begin
					rdyCnt[idx] <= rdyCnt[idx] + 1;
				end
				enqCnt[idx] <= 0;
			end
			else begin
				enqCnt[idx] <= enqCnt[idx] + 1;
			end

		end
	endrule

	//isEmpty no longer required because of enqTotal and deqTotal checks
	// adding isEmpty will make this rule conflict with applyenq
	rule applydeq;
		let idx = deqQ.first;
		if (deqCnt[idx]==fromInteger(thresh-1)) begin
			deqQ.deq;
			deqCnt[idx] <= 0;
		end 
		else begin
			deqCnt[idx] <= deqCnt[idx] + 1;
		end

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



	// No guards here. All safety checking is done in applyenq
	method Action enq(fifotype data, Bit#(vlog) idx); 
		enqInQ.enq(data);
		enqInIdxQ.enq(idx);
	endmethod
	
	method Action reqDeq(Bit#(vlog) idx);
		deqQ.enq(idx);
	endmethod

	method ActionValue#(fifotype) respDeq;
		let v <- fifoBuffer.portA.response.get();
		return v;
	endmethod

	method ActionValue#(Tuple2#(Bit#(vlog), Bit#(32))) getReadyIdx;
		readyIdxQ.deq;
		return readyIdxQ.first;
	endmethod

	// No guards here. safety checking must be done in user code
	// i.e. Only call when getReadyIdx returned
	//method Action startBurst(Bit#(TAdd#(1,TLog#(fifosize))) burstCount, Bit#(vlog) idx);
	//	deqTotal[idx] <= deqTotal[idx] + burstCount;
	//endmethod
endmodule
