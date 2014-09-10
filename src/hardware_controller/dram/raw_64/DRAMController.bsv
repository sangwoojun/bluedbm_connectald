package DRAMController;

import Clocks          :: *;
import XilinxVC707DDR3::*;
import Xilinx       :: *;

import FIFO::*;
import FIFOF::*;

interface DRAMControllerIfc;
	
	method Action write(Bit#(64) addr, Bit#(512) data, Bit#(7) bytes);

	method ActionValue#(Bit#(512)) read;
	method Action readReq(Bit#(64) addr, Bit#(7) bytes);
	interface Clock ddr_clk;
	interface Reset ddr_rst_n;
endinterface

module mkDRAMController#(DDR3_User_VC707 user) (DRAMControllerIfc);
	Clock clk <- exposeCurrentClock;
	Reset rst_n <- exposeCurrentReset;

	Clock ddr3_clk = user.clock;
	Reset ddr3_rstn = user.reset_n;

/*
	Reg#(Bit#(8)) curReqIdx <- mkReg(0);
	Reg#(Bit#(8)) procReqIdx <- mkReg(0);
	FIFO#(Bit#(8)) readReqOrderQ <- mkSizedFIFO(32);
	FIFO#(Bit#(8)) writeReqOrderQ <- mkSizedFIFO(32);
	*/
	
	SyncFIFOIfc#(Tuple3#(Bit#(64), Bit#(512), Bit#(64))) dramCDataInQ <- mkSyncFIFO(32, clk, rst_n, ddr3_clk);
	rule driverWrie;// (writeReqOrderQ.first == procReqIdx) ;
		dramCDataInQ.deq;
		let d = dramCDataInQ.first;
		user.request(truncate(tpl_1(d)), tpl_3(d), tpl_2(d));
				
		//procReqIdx <= procReqIdx + 1;
		//writeReqOrderQ.deq;
	endrule
	//FIXME dramCDataInQ and dramCDataOutQ might cause RAW hazard unless force ordered
	//probably will not happen, so left like this for now. FIXME!!
	SyncFIFOIfc#(Bit#(64)) dramCReadReqQ <- mkSyncFIFO(32, clk, rst_n, ddr3_clk);
	rule driverReadC; // (readReqOrderQ.first == procReqIdx);
		dramCReadReqQ.deq;
		Bit#(64) addr = dramCReadReqQ.first;
		user.request(truncate(addr), 0, 0);
			
		//procReqIdx <= procReqIdx + 1;
		//readReqOrderQ.deq;
	endrule
	SyncFIFOIfc#(Bit#(512)) dramCDataOutQ <- mkSyncFIFO(32, ddr3_clk, ddr3_rstn, clk);
	rule recvRead ;
		Bit#(512) res <- user.read_data;
		dramCDataOutQ.enq(res);
	endrule
	
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
		dramCDataInQ.enq(tuple3(rowidx<<3, (data<<(offset*8)), wmask<<offset));
	endmethod
	method Action readReq(Bit#(64) addr, Bit#(7) bytes);
		//curReqIdx <= curReqIdx + 1;
		//readReqOrderQ.enq(curReqIdx);

		//dramCReadReqQ.enq(tuple2(addr, bytes));
		Bit#(64) rowidx = addr>>6;
		dramCReadReqQ.enq(rowidx<<3);
	endmethod
	method ActionValue#(Bit#(512)) read;
		dramCDataOutQ.deq;
		return dramCDataOutQ.first;
	endmethod
	interface ddr_clk = clk;
	interface ddr_rst_n = rst_n;
endmodule

endpackage: DRAMController
