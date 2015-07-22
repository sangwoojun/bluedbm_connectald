import FIFOF::*;
import FIFO::*;
import FIFOLevel::*;
import BRAMFIFO::*;
import BRAM::*;
import GetPut::*;
import ClientServer::*;

import BRAMMultiRead::*;
import AuroraExtImport::*;
import ControllerTypes::*;
import AuroraCommon::*;
import MainTypes::*;

import Vector::*;


interface FlashServ;
	interface Put#(FlashCmdRoute) sendCmd;
	interface Get#(Tuple3#(Bit#(128), TagT, HeaderField)) readWord;
	interface Put#(Tuple3#(Bit#(128), TagT, HeaderField)) writeWord;
	interface Get#(WdReqT) writeDataReq;
	interface Get#(Tuple3#(TagT, StatusT, HeaderField)) ackStatus;
endinterface 

interface FlashCli;
	interface Get#(FlashCmdRoute) sendCmd;
	interface Put#(Tuple3#(Bit#(128), TagT, HeaderField)) readWord;
	interface Get#(Tuple3#(Bit#(128), TagT, HeaderField)) writeWord;
	interface Put#(WdReqT) writeDataReq;
	interface Put#(Tuple3#(TagT, StatusT, HeaderField)) ackStatus;
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
	Reg#(Bool) init <- mkReg(False);
	Reg#(TagT) initTagCnt <- mkReg(0);
	//Tag table and free tag queue
	FIFO#(TagT) freeTagQ <- mkSizedFIFO(num_tags);
	FIFOF#(TagT) freeTagRdQ <- mkSizedFIFOF(8);
	FIFOF#(TagT) freeTagAckQ <- mkSizedFIFOF(8);

	//tag -> srcnodeId, dstNodeId
	//BRAM2Port#(TagT, TagEntry) tagTable <- mkBRAM2Server(defaultValue);
	BRAMMultiRead#(TagT, TagEntry, 3) tagTable <- mkBRAMMultiRead(defaultValue);

	FIFO#(FlashCmdRoute) locCmdInQ <- mkFIFO();
	FIFO#(FlashCmdRoute) locCmdOutQ <- mkFIFO();
	FIFO#(FlashCmdRoute) remCmdOutQ <- mkFIFO();

	FIFO#(Tuple3#(Bit#(128), TagT, HeaderField)) locRdInQ <- mkSizedFIFO(4);
	FIFO#(TagT) locRdInTagQ <- mkFIFO();
	FIFO#(Tuple3#(Bit#(128), TagT, HeaderField)) locRdOutQ <- mkFIFO();
	FIFO#(Tuple3#(Bit#(128), TagT, HeaderField)) remRdInQ <- mkFIFO();
	FIFO#(Tuple3#(Bit#(128), TagT, HeaderField)) remRdOutQ <- mkFIFO();

	FIFO#(Tuple3#(TagT, StatusT, HeaderField)) locAckInQ <- mkSizedFIFO(4);
	FIFO#(Tuple3#(TagT, StatusT, HeaderField)) locAckOutQ <- mkFIFO();
	FIFO#(Tuple3#(TagT, StatusT, HeaderField)) remAckOutQ <- mkFIFO();

	FIFO#(WdReqT) locWreqInQ <- mkSizedFIFO(4);
	FIFO#(WdReqT) locWreqOutQ <- mkFIFO();
	FIFO#(WdReqT) remWreqOutQ <- mkFIFO();

	FIFO#(Tuple3#(Bit#(128), TagT, HeaderField)) locWdataInQ <- mkFIFO();
	FIFO#(Tuple3#(Bit#(128), TagT, HeaderField)) locWdataOutQ <- mkFIFO();
	FIFO#(Tuple3#(Bit#(128), TagT, HeaderField)) remWdataOutQ <- mkFIFO();


	//Initial populate freeTagQ
	rule initFreeTagQ if (!init);
		freeTagQ.enq(initTagCnt);
		initTagCnt <= initTagCnt + 1;
		if (initTagCnt == fromInteger(num_tags-1)) begin
			init <= True;
		end
	endrule
		
	//recycle free tags from all rules
	rule recycleTags if (init);
		if (freeTagRdQ.notEmpty) begin
			freeTagQ.enq(freeTagRdQ.first);
			freeTagRdQ.deq;
		end
		else if (freeTagAckQ.notEmpty) begin
			freeTagQ.enq(freeTagAckQ.first);
			freeTagAckQ.deq;
		end
	endrule
		
	//Command retagging
	rule renameTags if (init);
		let cmd = locCmdInQ.first();
		locCmdInQ.deq();
		let freeTag = freeTagQ.first();
		freeTagQ.deq();
		tagTable.wport.request.put(
			BRAMRequest{ write:True, 
							 responseOnWrite:False, 
							 address: freeTag,
							 datain: TagEntry{src: cmd.srcNode, dst: cmd.dstNode, origTag: cmd.fcmd.tag}
						 } );

		$display("[%d]: renamed origtag=%d, retag=%d", myNodeId, 
						cmd.fcmd.tag, freeTag);
		
		//repackage cmd with new tag
		cmd.fcmd.tag = freeTag;
		locCmdOutQ.enq(cmd);
	endrule

	//conflicts with retagRData but its ok
	rule mergeRd;
		locRdOutQ.enq(remRdInQ.first);
		remRdInQ.deq;
	endrule

	Vector#(NumTags, Reg#(Bit#(TLog#(PageWords)))) burstCnt <- replicateM(mkReg(0));
	FIFO#(Bool) rdataIsLastQ <- mkSizedFIFO(4);

	rule lookUpRData if (init);
		let ctag = locRdInTagQ.first;
		locRdInTagQ.deq();
		tagTable.rport[0].request.put( BRAMRequest{
												write: False,
												responseOnWrite:?,
												address: ctag,
												datain:?
											});
		if (burstCnt[ctag] == fromInteger(pageWords-1)) begin
			rdataIsLastQ.enq(True);
			burstCnt[ctag] <= 0;
		end
		else begin
			rdataIsLastQ.enq(False);
			burstCnt[ctag] <= burstCnt[ctag] + 1;
		end
	endrule
		

	rule retagRData if (init);
		match{.data, .ctag, .trash} = locRdInQ.first;
		locRdInQ.deq;

		let last = rdataIsLastQ.first;
		rdataIsLastQ.deq();
		if (last) begin
			//freeTagQ.enq(ctag); //recycle tag
			freeTagRdQ.enq(ctag);
		end

		let entry <- tagTable.rport[0].response.get();
		//the DEST of this burst is the SOURCE of the command!
		//Note: re-tag this burst with original tag
		let dataTagDst = tuple3(data, entry.origTag, entry.src);
		if (entry.src==myNodeId) begin
			locRdOutQ.enq(dataTagDst);
		end
		else begin
			remRdOutQ.enq(dataTagDst);
		end
	endrule

	//For writes, we rely on the sender of the write burst to 
	//send the RENAMED tag along with the data burst (instead 
	// of the original cmd tag)

	rule forwardWdata if (init);
		let wd = locWdataInQ.first;
		locWdataInQ.deq;
		if (tpl_3(wd) == myNodeId) begin
			locWdataOutQ.enq(wd);
		end
		else begin
			remWdataOutQ.enq(wd);
		end
	endrule

	rule forwardAck if (init);
		match{.ctag, .status, .trash} = locAckInQ.first;
		locAckInQ.deq;
		freeTagAckQ.enq(ctag); //recycle tag
		let entry <- tagTable.rport[1].response.get();
		let ack = tuple3(entry.origTag, status, entry.src);
		if (entry.src==myNodeId) begin
			locAckOutQ.enq(ack);
		end
		else begin
			remAckOutQ.enq(ack);
		end
	endrule

	rule forwardWreq if (init);
		let req = locWreqInQ.first;
		locWreqInQ.deq;
		let entry <- tagTable.rport[2].response.get();
		let reqOut = WdReqT{origTag: entry.origTag, reTag: req.reTag, src: myNodeId, dst: entry.src};
		if (entry.src==myNodeId) begin
			locWreqOutQ.enq(reqOut);
		end
		else begin
			remWreqOutQ.enq(reqOut);
		end
	endrule
		

	interface FlashServ locFlashServ;
		interface Put sendCmd;
			method Action put (FlashCmdRoute cmd);
				if (cmd.dstNode == myNodeId) begin
					locCmdInQ.enq(cmd);
				end
				else begin
					remCmdOutQ.enq(cmd);
				end
			endmethod
		endinterface

		interface readWord = toGet(locRdOutQ);
		interface writeWord = toPut(locWdataInQ);
		interface writeDataReq = toGet(locWreqOutQ); 
		interface ackStatus = toGet(locAckOutQ);
	endinterface

	interface FlashCli locFlashCli;
		interface sendCmd = toGet(locCmdOutQ);
		interface Put readWord;
			method Action put (Tuple3#(Bit#(128), TagT, HeaderField) d);
				locRdInQ.enq(d); 
				locRdInTagQ.enq(tpl_2(d));
			endmethod
		endinterface
		
		interface writeWord = toGet(locWdataOutQ);

		interface Put writeDataReq; 
			method Action put (WdReqT req);
				tagTable.rport[2].request.put( BRAMRequest{
														write: False,
														responseOnWrite:?,
														address: req.reTag,//tag coming from controller
														datain:?
													});
				locWreqInQ.enq(req);
			endmethod
		endinterface

		interface Put ackStatus;
		  	method Action put (Tuple3#(TagT, StatusT, HeaderField) ack);
				tagTable.rport[1].request.put( BRAMRequest{
														write: False,
														responseOnWrite:?,
														address: tpl_1(ack),
														datain:?
													});
				locAckInQ.enq(ack);
			endmethod
		endinterface
				
	endinterface

	interface FlashServ remFlashServ;
		interface sendCmd = toPut(locCmdInQ);
		interface readWord = toGet(remRdOutQ);
		interface writeWord = toPut(locWdataOutQ); //direct
		interface writeDataReq = toGet(remWreqOutQ);
		interface ackStatus = toGet(remAckOutQ);
	endinterface

	interface FlashCli remFlashCli;
		interface sendCmd = toGet(remCmdOutQ);
		interface readWord = toPut(remRdInQ);
		interface writeWord = toGet(remWdataOutQ); 
		interface writeDataReq = toPut(locWreqOutQ); //directly put to localQ
		interface ackStatus = toPut(locAckOutQ); //directly put to localQ
	endinterface

	method Action setNodeId (HeaderField myId);
		myNodeId <= myId;
	endmethod
endmodule

