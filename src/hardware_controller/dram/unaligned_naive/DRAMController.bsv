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

	Reg#(Bit#(8)) curReqIdx <- mkReg(0);
	Reg#(Bit#(8)) procReqIdx <- mkReg(0);
	FIFO#(Bit#(8)) readReqOrderQ <- mkSizedFIFO(32);
	FIFO#(Bit#(8)) writeReqOrderQ <- mkSizedFIFO(32);
	
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
	
	SyncFIFOIfc#(Bit#(512)) dramCDataOutQ <- mkSyncFIFO(32, ddr3_clk, ddr3_rstn, clk);
	FIFO#(Bit#(512)) dataOutQ <- mkFIFO();

	Reg#(Bit#(512)) writeBuffer <- mkReg(0);
	Reg#(Bit#(64)) writeMask <- mkReg(0);
	Reg#(Bit#(64)) writeIdx <- mkReg(0);
	
	SyncFIFOIfc#(Bit#(64)) dramCReadReqQ <- mkSyncFIFO(32, clk, rst_n, ddr3_clk);
	FIFO#(Tuple2#(Bit#(64), Bit#(7))) readReqQ <- mkSizedFIFO(32);
	//FIFO#(Bit#(64)) readInFlightQ <- mkFIFO(clocked_by ddr3_clk, reset_by ddr3_rstn);
	FIFOF#(Bit#(64)) readOffsetQ <- mkSizedFIFOF(32);
	Reg#(Bit#(64)) lastReadIdx <- mkReg(~0);
	FIFOF#(Bool) readNewQ <- mkSizedFIFOF(32);

	Reg#(Bit#(1)) readRowNext <- mkReg(0);
	rule driveRead (readReqOrderQ.first == procReqIdx );
		let ii = readReqQ.first;
		Bit#(64) addr = tpl_1(ii);
		Bit#(7) bytes = tpl_2(ii);
		Bit#(64) mask = case (bytes) 
			1: 64'b1;
			2: 64'b11;
			4: 64'b1111;
			8: 64'b11111111;
			64: ~64'h0;
			default: 0;
			endcase;

		let rowidx = addr>>6; // 64 bytes per row
		let offset = addr & extend(6'b111111);
		Bit#(64) fmask = mask <<offset;
		Bit#(512) fdata = writeBuffer>>(offset*8);

		if ( readRowNext == 1 ) begin
			readNewQ.enq(True);
			readOffsetQ.enq(truncate(offset));

			readRowNext <= 0;
			
			dramCReadReqQ.enq(truncate((rowidx+1)<<3));
			
			procReqIdx <= procReqIdx + 1;
			readReqOrderQ.deq;
			readReqQ.deq;
		end
		else if ( writeMask > 0 && rowidx == writeIdx ) begin
			if ( ( (fmask & writeMask) == fmask )
				&& ( extend(bytes) + offset <= 64 )) begin

				if ( !readOffsetQ.notEmpty() ) begin
					dataOutQ.enq(fdata);
					readReqQ.deq;
				
					procReqIdx <= procReqIdx + 1;
					readReqOrderQ.deq;
				end
			end else begin
				dramCDataInQ.enq(tuple3(writeIdx<<3, writeBuffer, writeMask));
				writeMask <= 0;
			end
		end else begin
			//dramCReadReqQ.deq;
			//user.request(truncate(rowidx<<3), 0, 0);
			readOffsetQ.enq(truncate(offset));
			if ( lastReadIdx == rowidx ) begin
				readNewQ.enq(False);
				
				procReqIdx <= procReqIdx + 1;
				readReqOrderQ.deq;
				readReqQ.deq;
			end
			else begin // if readRowNext == 0
				readNewQ.enq(True);
				lastReadIdx <= rowidx;
				readRowNext <= 1;
				dramCReadReqQ.enq(truncate(rowidx<<3));
			end
		end
	endrule
	rule driverReadC; // (readReqOrderQ.first == procReqIdx);
		dramCReadReqQ.deq;
		Bit#(64) addr = dramCReadReqQ.first;
		user.request(truncate(addr), 0, 0);
			
		//procReqIdx <= procReqIdx + 1;
		//readReqOrderQ.deq;
	endrule
	
	rule recvRead ;
		Bit#(512) res <- user.read_data;
		dramCDataOutQ.enq(res);
	endrule
	Reg#(Bit#(TMul#(512,2))) readCache <- mkReg(0);
	Reg#(Bit#(1)) readRowNextC <- mkReg(0);
	rule recvRead2 ;
		Bit#(512) data = dramCDataOutQ.first;
		if ( readNewQ.first == True ) begin
			Bit#(512) bmask = ~0;
			
			if ( readRowNextC == 0 ) begin
				//readCache <= (readCache&(extend(bmask)<<512)) | {bmask,data};
				readCache <= zeroExtend(data);
				readRowNextC <= 1;
			end else begin
				let fdat = readCache + (zeroExtend(data)<<512);
				//let fdat = (readCache&extend(bmask)) | {data,bmask};
				readCache <= fdat;
				readRowNextC <= 0;
				
				dataOutQ.enq(truncate(fdat>>(readOffsetQ.first*8)));
			end
			dramCDataOutQ.deq;
		end else begin
			dataOutQ.enq(truncate(readCache>>(readOffsetQ.first*8)));
		end

		readOffsetQ.deq;
		readNewQ.deq;
	endrule

	
	FIFO#(Tuple3#(Bit#(64), Bit#(512), Bit#(7))) dataInQ <- mkFIFO();
	rule driverWriteL (writeReqOrderQ.first == procReqIdx);
		let di = dataInQ.first;
		Bit#(64) addr = tpl_1(di);
		Bit#(512) data = tpl_2(di);
		Bit#(7) bytes = tpl_3(di);
		Bit#(64) mask = case (bytes) 
			1: 64'b1;
			2: 64'b11;
			4: 64'b1111;
			8: 64'b11111111;
			64: ~64'h0;
			default: 0;
			endcase;

		let rowidx = addr>>6; // 64 bytes per row
		let offset = addr & extend(6'b111111);
		Bit#(64) fmask = mask <<offset;
		Bit#(512) fdata = data<<(offset*8);
		if ( rowidx == writeIdx ) begin
			//if ( offset == 0 ) begin
			if ( mask == 0 ) begin
				dataInQ.deq;
				procReqIdx <= procReqIdx + 1;
				writeReqOrderQ.deq;
			end
			else if ( extend(bytes) + offset <= 64 ) begin
				Bit#(512) td = writeBuffer;
				for ( int i = 0; i < 64; i = i + 1) begin
					int idx = i * 8;
					if ( fmask[i] == 1 ) begin
						Bit#(8) tb = fdata[idx+7:idx];
						td[idx+7:idx] = tb;//fdata[idx+7:idx];
					end
				end
				writeBuffer <= td;
				writeMask <= writeMask | fmask;
				dataInQ.deq;
				
				procReqIdx <= procReqIdx + 1;
				writeReqOrderQ.deq;
			end else if ( writeMask == 0 ) begin
				dramCDataInQ.enq(tuple3(rowidx<<3, fdata, fmask));
				writeBuffer <= data >> (512-(offset*8));
				writeMask <= mask >> (64-offset);
				writeIdx <= rowidx + 1;

				dataInQ.deq;
				procReqIdx <= procReqIdx + 1;
				writeReqOrderQ.deq;
			end else begin
				dramCDataInQ.enq(tuple3(writeIdx<<3, writeBuffer, writeMask));
				writeMask <= 0;
			end
		end else begin
			if ( writeMask > 0 ) begin
				dramCDataInQ.enq(tuple3(writeIdx<<3, writeBuffer, writeMask));
			end
			writeMask <= 0;
			writeIdx <= rowidx;
		end
	endrule

	method Action write(Bit#(64) addr, Bit#(512) data, Bit#(7) bytes);
		dataInQ.enq(tuple3(addr, data, bytes));
		curReqIdx <= curReqIdx + 1;
		writeReqOrderQ.enq(curReqIdx);
	endmethod
	method Action readReq(Bit#(64) addr, Bit#(7) bytes);
		readReqQ.enq(tuple2(addr, bytes));
		curReqIdx <= curReqIdx + 1;
		readReqOrderQ.enq(curReqIdx);
		//dramCReadReqQ.enq(tuple2(addr, bytes));
		//dramCReadReqQ.enq((addr&extend(~6'b111111)));
	endmethod
	method ActionValue#(Bit#(512)) read;
		//dramCDataOutQ.deq;
		dataOutQ.deq;
		//return dramCDataOutQ.first;
		return dataOutQ.first;
	endmethod
	interface ddr_clk = clk;
	interface ddr_rst_n = rst_n;
endmodule

endpackage: DRAMController
