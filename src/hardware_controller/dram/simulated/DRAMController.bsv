package DRAMController;

import Clocks          :: *;

import FIFO::*;
import FIFOF::*;
import RegFile::*;

interface DRAMControllerIfc;
	
	method Action write(Bit#(64) addr, Bit#(512) data, Bit#(7) bytes);

	method ActionValue#(Bit#(512)) read;
	method Action readReq(Bit#(64) addr, Bit#(7) bytes);
	interface Clock ddr_clk;
	interface Reset ddr_rst_n;
endinterface

module mkDRAMController (DRAMControllerIfc);
	Clock clk <- exposeCurrentClock;
	Reset rst_n <- exposeCurrentReset;

	RegFile#(Bit#(16), Bit#(512)) dram <- mkRegFileFull;
	Reg#(Maybe#(Bit#(512))) readT <- mkReg(tagged Invalid);


	method Action write(Bit#(64) addr, Bit#(512) data, Bit#(7) bytes);
		//curReqIdx <= curReqIdx + 1;
		//writeReqOrderQ.enq(curReqIdx);
		
		let offset = addr & extend(6'b111111);
		
		Bit#(64) wmask = case (bytes) 
			1: 64'b1;
			2: 64'b11;
			4: 64'b1111;
			8: 64'b11111111;
			64: ~64'h0;
			default: 0;
			endcase;
		Bit#(64) rowidx = addr>>6;
		dram.upd(truncate(rowidx), data);
		//dramCDataInQ.enq(tuple3(rowidx<<3, (data<<(offset*8)), wmask<<offset));
	endmethod
	method Action readReq(Bit#(64) addr, Bit#(7) bytes);
		//curReqIdx <= curReqIdx + 1;
		//readReqOrderQ.enq(curReqIdx);

		//dramCReadReqQ.enq(tuple2(addr, bytes));
		Bit#(64) rowidx = addr>>6;
		readT <= tagged Valid dram.sub(truncate(rowidx));
		//dramCReadReqQ.enq(rowidx<<3);
	endmethod
	method ActionValue#(Bit#(512)) read if (isValid(readT));
		let data = fromMaybe(0, readT);
		readT <= tagged Invalid;
		//dramCDataOutQ.deq;
		//return dramCDataOutQ.first;
		return data;
	endmethod
	interface ddr_clk = clk;
	interface ddr_rst_n = rst_n;
endmodule

endpackage: DRAMController
