import ClientServer::*;
import GetPut::*;
import Clocks          :: *;

import Vector::*;
import FIFO::*;

import DRAMImporter::*;

typedef 4 IdxWidth;

typedef struct {
Bit#(32) addr;
Bit#(IdxWidth) idx;
} DRAMReadCmd deriving (Bits,Eq);
typedef struct {
Bit#(32) addr;
Bit#(512) data;
Bit#(IdxWidth) idx;
} DRAMWriteCmd deriving (Bits,Eq);

interface DRAMUserIfc;
	method Action writeReq(Bit#(32) addr, Bit#(512) data);
	method Action readReq(Bit#(32) addr);
	method ActionValue#(Bit#(512)) readResp;
endinterface
interface DRAMCommandIfc;
	method ActionValue#(DRAMWriteCmd) writeReq;
	method ActionValue#(DRAMReadCmd) readReq;
	method Action readResp(Bit#(512) data);
endinterface
interface DRAMEndpointIfc;
	interface DRAMUserIfc user;
	interface DRAMCommandIfc cmd;
endinterface

interface DRAMArbiterIfc;
endinterface

//module mkDRAMArbiter#(Vector#(portCount, Client#(Bit#(64), Bit#(512))) userList) (DRAMArbiterIfc#(portNum));
module mkDRAMArbiter#(DRAM_User dram, Vector#(tPortCount, DRAMCommandIfc) userList) (DRAMArbiterIfc);
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;


	Integer portCount = valueOf(tPortCount);
	
	Clock ddr3clk = dram.clock;
	Reset ddr3rstn = dram.reset_n;
	
	FIFO#(Bit#(8)) reqUserQ <- mkSizedFIFO(32, clocked_by ddr3clk, reset_by ddr3rstn);

	Reg#(Bit#(8)) rrCounter <- mkReg(0);
	rule increaseRRCounter;
		if ( rrCounter + 1 >= fromInteger(portCount) ) begin
			rrCounter <= 0;
		end else begin
			rrCounter <= rrCounter + 1;
		end
	endrule

	for ( Integer uidx = 0; uidx < portCount; uidx = uidx + 1) begin
		Reg#(Bit#(IdxWidth)) nextIdx <- mkReg(0, clocked_by ddr3clk, reset_by ddr3rstn);
		//FIFO#(DRAMWriteCmd) wcmdQ <- mkFIFO;
		//FIFO#(DRAMReadCmd) rcmdQ <- mkFIFO;
		SyncFIFOIfc#(DRAMWriteCmd) wcmdQ <- mkSyncFIFO(2, curClk, curRst, ddr3clk);
		SyncFIFOIfc#(DRAMReadCmd) rcmdQ <- mkSyncFIFO(2, curClk, curRst, ddr3clk);
		let user = userList[uidx];

		rule ruleGetReadCmd;
			let cmd <- user.readReq;
			rcmdQ.enq(cmd);
		endrule
		rule ruleGetWriteCmd;
			let cmd <- user.writeReq;
			wcmdQ.enq(cmd);
		endrule
		rule applyRead ( dram.init_done 
			&& rcmdQ.first.idx == nextIdx );
			let rcmd = rcmdQ.first;
			if ( rcmd.idx == nextIdx ) begin
				//$display ( "read cmd at %d withd id %d/%d", uidx, rcmd.idx, nextIdx );
				nextIdx <= nextIdx + 1;
				rcmdQ.deq;
				reqUserQ.enq(fromInteger(uidx));
				let addr = rcmd.addr;
				
				dram.request(truncate(addr<<3), 0, 0);
			end
		endrule
		rule applyWrite ( dram.init_done 
			&& wcmdQ.first.idx == nextIdx); 

			let wcmd = wcmdQ.first;
			if ( wcmd.idx == nextIdx ) begin
				//$display ( "write cmd at %d withd id %d/%d", uidx, wcmd.idx, nextIdx );
				nextIdx <= nextIdx + 1;
				wcmdQ.deq;
				let addr = wcmd.addr;
				//reqUserQ.enq(fromInteger(uidx));
				dram.request(truncate(addr<<3), ~64'h0, wcmd.data);
			end

		endrule
	end

/*
	Reg#(Bit#(32)) testPumpDataIdx <- mkReg(0, clocked_by ddr3clk, reset_by ddr3rstn);
	rule testpumpdata (testPumpDataIdx < 16 );
		testPumpDataIdx <= testPumpDataIdx + 1;
		reqUserQ.enq(fromInteger(0));
		dram.request(truncate(testPumpDataIdx<<3), 0, 0);
	endrule
	*/

	SyncFIFOIfc#(Tuple2#(Bit#(512), Bit#(8))) dataQ <- mkSyncFIFO(2, ddr3clk,ddr3rstn, curClk);
	rule ruleRecvData;
		let res <- dram.read_data;
		reqUserQ.deq;
		let uidx = reqUserQ.first;
		dataQ.enq(tuple2(res, uidx));
	endrule
	rule ruleSendData;
		let res = dataQ.first;
		dataQ.deq;
		let uidx = tpl_2(res);
		let dat = tpl_1(res);
		userList[uidx].readResp(dat);
		//$display ( "got read result to %d!", uidx );
	endrule
endmodule


module mkDRAMUser (DRAMEndpointIfc);

	Reg#(Bit#(IdxWidth)) nextIdx <- mkReg(0);
	FIFO#(DRAMWriteCmd) wcmdQ <- mkFIFO;
	FIFO#(DRAMReadCmd) rcmdQ <- mkFIFO;
	FIFO#(Bit#(512)) dataQ <- mkFIFO;



	interface DRAMUserIfc user;
		method Action writeReq(Bit#(32) addr_, Bit#(512) data);
			DRAMWriteCmd cmd = DRAMWriteCmd{addr:addr_, data:data, idx:nextIdx};
			nextIdx <= nextIdx + 1;
			wcmdQ.enq(cmd);
		endmethod
		method Action readReq(Bit#(32) addr_);
			DRAMReadCmd cmd = DRAMReadCmd{addr:addr_, idx:nextIdx};
			nextIdx <= nextIdx + 1;
			rcmdQ.enq(cmd);
		endmethod
		method ActionValue#(Bit#(512)) readResp;
			dataQ.deq;
			return dataQ.first;
		endmethod
	endinterface
	interface DRAMCommandIfc cmd;
		method ActionValue#(DRAMWriteCmd) writeReq;
			wcmdQ.deq;
			return wcmdQ.first;
		endmethod
		method ActionValue#(DRAMReadCmd) readReq;
			rcmdQ.deq;
			return rcmdQ.first;
		endmethod
		method Action readResp(Bit#(512) data);
			dataQ.enq(data);
		endmethod
	endinterface
endmodule
