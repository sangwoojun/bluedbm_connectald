import FIFOF::*;
import FIFO::*;
import FIFOLevel::*;
import BRAMFIFO::*;
import BRAM::*;
import GetPut::*;
import ClientServer::*;

import AuroraExtImport::*;
import ControllerTypes::*;
import AuroraCommon::*;
import MainTypes::*;

import Vector::*;

interface FlashCli;
	method ActionValue#(FlashCmdRoute) sendCmd();
	method Action readWord(Tuple3#(Bit#(128), TagT, HeaderField) d);
endinterface

interface FlashServ;
	method Action sendCmd (FlashCmdRoute cmd);
	method ActionValue#(Tuple3#(Bit#(128), TagT, HeaderField)) readWord ();
endinterface 

interface FlashSplitterIfc;
	interface FlashServ locFlashServ;
	interface FlashCli	locFlashCli;
	interface FlashServ remFlashServ;
	interface FlashCli	remFlashCli;
	method Action setNodeId (HeaderField myId);
endinterface

module mkFlashSplitter(FlashSplitterIfc);
	
	Reg#(HeaderField) myNodeId <- mkReg(0);
	//Tag table. Does not rename at this moment
	//tag -> srcnodeId, dstNodeId
	BRAM2Port#(TagT, Tuple2#(HeaderField, HeaderField)) tagTable <- mkBRAM2Server(defaultValue);

	FIFO#(FlashCmdRoute) locCmdOutQ <- mkFIFO();
	FIFO#(FlashCmdRoute) remCmdOutQ <- mkFIFO();

	FIFO#(Tuple3#(Bit#(128), TagT, HeaderField)) locRdInQ <- mkFIFO();
	FIFO#(Tuple3#(Bit#(128), TagT, HeaderField)) locRdOutQ <- mkFIFO();
	FIFO#(Tuple3#(Bit#(128), TagT, HeaderField)) remRdInQ <- mkFIFO();
	//FIFO#(Tuple2#(Bit#(128), TagT)) remRdInQ <- mkFIFO();
	FIFO#(Tuple3#(Bit#(128), TagT, HeaderField)) remRdOutQ <- mkFIFO();

	//conflicts with fwdRData but its ok
	rule mergeRd;
		locRdOutQ.enq(remRdInQ.first);
		remRdInQ.deq;
	endrule

	rule fwdRData;
		let srcdst <- tagTable.portA.response.get();
		match{.src, .dst} = srcdst;
		match{.data, .tag, .trash} = locRdInQ.first;
		locRdInQ.deq;
		//the DEST of this burst is the SOURCE of the command!
		let dataTagDst = tuple3(data, tag, src);
		if (src==myNodeId) begin
			locRdOutQ.enq(dataTagDst);
		end
		else begin
			remRdOutQ.enq(dataTagDst);
		end
	endrule

	interface FlashServ locFlashServ;
		method Action sendCmd (FlashCmdRoute cmd);
			if (cmd.dstNode == myNodeId) begin
				locCmdOutQ.enq(cmd);
			end
			else begin
				remCmdOutQ.enq(cmd);
			end
		endmethod

		method ActionValue#(Tuple3#(Bit#(128), TagT, HeaderField)) readWord ();
			locRdOutQ.deq;
			return locRdOutQ.first;
		endmethod
	endinterface

	interface FlashCli locFlashCli;
		method ActionValue#(FlashCmdRoute) sendCmd();
			let cmd = locCmdOutQ.first;
			tagTable.portB.request.put(BRAMRequest{
											write:True, 
											responseOnWrite:False, 
											address: cmd.fcmd.tag,
											datain: tuple2(cmd.srcNode, cmd.dstNode)
										});
			locCmdOutQ.deq();
			return cmd;
		endmethod
		method Action readWord(Tuple3#(Bit#(128), TagT, HeaderField) d);
			locRdInQ.enq(d); 
			tagTable.portA.request.put( BRAMRequest{
												write: False,
												responseOnWrite:?,
												address: tpl_2(d),
												datain:?
											});
		endmethod

	endinterface

	interface FlashServ remFlashServ;
		method Action sendCmd (FlashCmdRoute cmd);
			locCmdOutQ.enq(cmd);
		endmethod

		method ActionValue#(Tuple3#(Bit#(128), TagT, HeaderField)) readWord ();
			remRdOutQ.deq;
			return remRdOutQ.first;
		endmethod
	endinterface

	interface FlashCli	remFlashCli;
		method ActionValue#(FlashCmdRoute) sendCmd();
			remCmdOutQ.deq();
			return remCmdOutQ.first;
		endmethod
		method Action readWord(Tuple3#(Bit#(128), TagT, HeaderField) d);
			//locRdOutQ.enq(d);
			remRdInQ.enq(d);
		endmethod
	endinterface

	method Action setNodeId (HeaderField myId);
		myNodeId <= myId;
	endmethod
endmodule

