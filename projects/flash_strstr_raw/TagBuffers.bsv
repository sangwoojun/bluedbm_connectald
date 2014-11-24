import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import BRAM::*;
import Gearbox::*;
import BRAMFIFO::*;
import Connectable::*;
import StmtFSM::*;
import Pipe::*;

import ControllerTypes::*;

/*
typedef struct {
	Bit#(FlashAddrWidth) startAddr;
	Bit#(FlashAddrWidth) len;
} FlashClientReq deriving (Bits, Eq);


interface FlashReadClient#(dataWidth);
	interface Get#(FlashClientReq) flashClientReq;
	interface Put#(Bit#(dataWidth)) rdata; 
	interface Put#(Bool) done;
endinterface
*/
typedef TLog#(PageWords) PageOffsetSz;
typedef struct {
	FlashAddr faddr;
	Bit#(PageOffsetSz) offset;
} PageAddrOff deriving (Bits, Eq);

function PageAddrOff transAddr(Bit#(FlashAddrWidth) addr);
	//byte addressible
	Tuple2#(PageAddrOff, Bit#(TLog#(WordBytes))) decodedAddr = unpack(truncate(addr));
	return tpl_1(decodedAddr);
endfunction


interface FlashReadServer#(numeric type dataWidth);
	interface Put#(FlashClientReq) flashClientReq;
	interface Get#(Bit#(dataWidth)) rdata; 
	interface Get#(Bool) done;
endinterface

interface TagBuffers;
	interface Vector#(NumMpEngines, FlashReadServer#(WordSz)) flash_servers;
	interface Get#(FlashCmd) flashReq;
	interface Put#(Tuple2#(Bit#(WordSz), TagT)) readResp;
endinterface

module mkTagBuffers(TagBuffers);

	Vector#(NumMpEngines, FIFO#(Bit#(WordSz))) bufferQs <- replicateM(mkSizedBRAMFIFO(pageWords));
	Vector#(NumMpEngines, FIFO#(FlashClientReq)) flashClientReqQs <- replicateM(mkFIFO);
	Vector#(NumMpEngines, FIFO#(Bool)) doneQs <- replicateM(mkFIFO);
	Vector#(NumMpEngines, FIFO#(FlashCmd)) flashCmdQs <- replicateM(mkFIFO());
	FIFO#(FlashCmd) flashAggrCmdQ <- mkFIFO();
	FIFO#(Tuple2#(Bit#(WordSz), TagT)) flashReadQ <- mkFIFO();
	Vector#(NumMpEngines, Reg#(Bit#(FlashAddrWidth))) bytesRequested <- replicateM(mkReg(0));
	Vector#(NumMpEngines, Reg#(Bit#(FlashAddrWidth))) bytesReceived <- replicateM(mkReg(0));
	Vector#(NumMpEngines, Reg#(Bit#(FlashAddrWidth))) cmdBytesRequested <- replicateM(mkReg(0));

	for (Integer i=0; i<valueOf(NumMpEngines); i=i+1) begin
		rule handleClientReq if (bytesRequested[i]-bytesReceived[i]==0);
			let req = flashClientReqQs[i].first;
			if (cmdBytesRequested[i] < req.len) begin
				Bit#(FlashAddrWidth) addrByte = req.startAddr + cmdBytesRequested[i];
				PageAddrOff addrFlash = transAddr(addrByte);
				if (addrFlash.offset != 0) begin
					$display("**ERROR: unaligned page reads unsupported!!");
				end
				
				$display("TagBuffers: FlashRequest issued for: ftag=%d, bus=%d, chip=%d, blk=%d, page=%d", 
					i, addrFlash.faddr.bus, addrFlash.faddr.chip, addrFlash.faddr.block, addrFlash.faddr.page);
				$display("TagBuffers: Client Request is: addr=%x, len=%d", req.startAddr, req.len);

				FlashCmd fcmd = FlashCmd {
					tag: fromInteger(i), //Use the ID as the tag. Only one tag per client
					op: READ_PAGE,
					bus: addrFlash.faddr.bus,
					chip: addrFlash.faddr.chip,
					block: addrFlash.faddr.block,
					page: addrFlash.faddr.page
				};
				//flashCmdQ.enq(fcmd);
				flashCmdQs[i].enq(fcmd);
				bytesRequested[i] <= bytesRequested[i] + fromInteger(pageSizeUser);
				cmdBytesRequested[i] <= cmdBytesRequested[i] + fromInteger(pageSizeUser);
			end
			else begin
				cmdBytesRequested[i] <= 0;
				flashClientReqQs[i].deq;
				doneQs[i].enq(True);
				$display("TagBuffers: Done with req");
			end
		endrule
		
		rule aggrFlashCmd;
			flashCmdQs[i].deq;
			flashAggrCmdQ.enq(flashCmdQs[i].first);
		endrule

	end //for each mp engine


	rule handleFlashResp; 
		let tag = tpl_2(flashReadQ.first);
		let data = tpl_1(flashReadQ.first);
		flashReadQ.deq;
		Bit#(TLog#(NumMpEngines)) tagTrunc = truncate(tag);
		bufferQs[tagTrunc].enq(data);
		bytesReceived[tagTrunc] <= bytesReceived[tag] + fromInteger(wordBytes);
		$display("TagBuffers: got tag=%d, truncTag=%d, data=%x", tag, tagTrunc, data);
	endrule

	function FlashReadServer#(WordSz) mkm(Integer i) = (
		interface FlashReadServer#(WordSz);
			interface Put flashClientReq = toPut(flashClientReqQs[i]);
			interface Get rdata = toGet(bufferQs[i]);
			interface Get done = toGet(doneQs[i]);
		endinterface
			);


	interface Get flashReq = toGet(flashAggrCmdQ);
	interface Put readResp = toPut(flashReadQ);
	interface flash_servers = map(mkm, genVector);
endmodule



