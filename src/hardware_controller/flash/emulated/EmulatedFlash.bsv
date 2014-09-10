package EmulatedFlash;

import FIFO::*;
import Clocks::*;
import Vector::*;

import DRAMController::*;
import Interface::*;

interface FlashInterfaceIfc;
	method Action readPage(Bit#(5) bus, Bit#(5) chip, Bit#(16) block, Bit#(8) page, Bit#(8) tag);
	method Action writePage(Bit#(5) bus, Bit#(5) chip, Bit#(16) block, Bit#(8) page, Bit#(8) tag);
	method Action eraseBlock(Bit#(5) bus, Bit#(5) chip, Bit#(16) block);

	method Action writeWord(Bit#(64) data, Bit#(8) tag);
	method ActionValue#(Tuple2#(Bit#(64),Bit#(8))) readWord;
endinterface

module mkEmulatedFlash#(DRAMControllerIfc dram, FlashControllerIfc flash) (FlashInterfaceIfc);
	Clock dram_clk = dram.ddr_clk;
	Reset dram_rst_n = dram.ddr_rst_n;

	Reg#(Bit#(64)) curReadAddr <- mkReg(0, clocked_by dram_clk, reset_by dram_rst_n);
	Reg#(Bit#(8)) curReadTag <- mkReg(0, clocked_by dram_clk, reset_by dram_rst_n);
	Reg#(Bit#(32)) curReadCount <- mkReg(0, clocked_by dram_clk, reset_by dram_rst_n);

	SyncFIFOIfc#(Tuple2#(Bit#(64),Bit#(8))) readReqQ <- mkSyncFIFOFromCC(16, dram_clk);
	SyncFIFOIfc#(Tuple2#(Bit#(64),Bit#(8))) writeReqQ <- mkSyncFIFOFromCC(16, dram_clk);

	rule startRead(curReadCount == 0);
		let d = readReqQ.first;
		curReadAddr <= tpl_1(d);
		curReadTag <= tpl_2(d);
		curReadCount <= 8192;

		readReqQ.deq;
	endrule
	FIFO#(Bit#(8)) readTagQ <- mkSizedFIFO(32, clocked_by dram_clk, reset_by dram_rst_n);
	rule driveRead (curReadCount > 0);
		curReadCount <= curReadCount - 64;
		curReadAddr <= curReadAddr + 64;
		readTagQ.enq(curReadTag);

		dram.readReq(curReadAddr, 64);
	endrule

	SyncFIFOIfc#(Tuple2#(Bit#(512),Bit#(8))) readResQ <- mkSyncFIFOToCC(16, dram_clk, dram_rst_n);
	rule recvRead;
		let dr <- dram.read;
		Bit#(512) rr = dr;
		readResQ.enq(tuple2(rr, readTagQ.first));
		readTagQ.deq;
	endrule
	Reg#(Bit#(512)) readSerializeBuf <- mkReg(0);
	Reg#(Bit#(8)) readSerializeIdx <- mkReg(0);
	Reg#(Bit#(8)) readSerializeTag <- mkReg(0);
	rule serializeReadStart ( readSerializeIdx == 0 );
		Bit#(512) dat = tpl_1(readResQ.first);
		Bit#(8) tag = tpl_2(readResQ.first);

		readResQ.deq;
		readSerializeIdx <= 8; // 64/8
		readSerializeTag <= tag;
		readSerializeBuf <= dat;
	endrule

	FIFO#(Tuple2#(Bit#(64), Bit#(8))) serializedReadResQ <- mkSizedFIFO(8);

	rule serializeRead ( readSerializeIdx > 0 );
		Bit#(64) data = truncate(readSerializeBuf);
		readSerializeBuf <= readSerializeBuf>>64;
		readSerializeIdx <= readSerializeIdx - 1;
		serializedReadResQ.enq(tuple2(data, readSerializeTag));
	endrule

	Vector#(64, Reg#(Bit#(64))) writeOff <- replicateM(mkReg(0), clocked_by dram_clk, reset_by dram_rst_n);
	SyncFIFOIfc#(Tuple2#(Bit#(64),Bit#(8))) writeDataQ <- mkSyncFIFOFromCC(32, dram_clk);
	rule startWrite;
		writeReqQ.deq;
		let d = writeReqQ.first;
		let addr = tpl_1(d);
		let tag = tpl_2(d);
		writeOff[tag] <= addr;
	endrule
	rule driveWrite;
		writeDataQ.deq;
		let d = writeDataQ.first;
		let data = tpl_1(d);
		let tag = tpl_2(d);

		let wo = writeOff[tag];
		writeOff[tag] <= wo + 8;

		dram.write(wo, extend(data), 8);
	endrule
	
	method Action readPage(Bit#(5) bus, Bit#(5) chip, Bit#(16) block, Bit#(8) page, Bit#(8) tag);
		Bit#(64) pageE = extend(page)<<13;
		Bit#(64) blockE = extend(block)<<(13+8);
		Bit#(64) chipE = extend(chip)<<(13+8+12/*per LUN*/+2);
		Bit#(64) busE = extend(bus)<<(13+8+12+2+2);

		Bit#(64) byteaddr = pageE+blockE+chipE+busE;

		readReqQ.enq(tuple2(byteaddr,tag));
	endmethod
	method Action writePage(Bit#(5) bus, Bit#(5) chip, Bit#(16) block, Bit#(8) page, Bit#(8) tag);
		Bit#(64) pageE = extend(page)<<13;
		Bit#(64) blockE = extend(block)<<(13+8);
		Bit#(64) chipE = extend(chip)<<(13+8+12/*per LUN*/+2);
		Bit#(64) busE = extend(bus)<<(13+8+12+2+2);

		Bit#(64) byteaddr = pageE+blockE+chipE+busE;

		writeReqQ.enq(tuple2(byteaddr,tag));
	endmethod
	method Action eraseBlock(Bit#(5) bus, Bit#(5) chip, Bit#(16) block);
	endmethod
	
	method Action writeWord(Bit#(64) data, Bit#(8) tag);
		writeDataQ.enq(tuple2(data,tag));
	endmethod
	method ActionValue#(Tuple2#(Bit#(64), Bit#(8))) readWord;
		serializedReadResQ.deq;
		return serializedReadResQ.first;
		//readResQ.deq;
		//return readResQ.first;
	endmethod
	
endmodule

endpackage : EmulatedFlash
