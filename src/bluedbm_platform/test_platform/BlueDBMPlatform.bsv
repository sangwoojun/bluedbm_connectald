import FIFO::*;
import Clocks::*;
import Vector::*;

import PlatformInterfaces::*;
import Interface::*;

import I2CSimple::*;

import DRAMController::*;
import PageCache::*;
import EmulatedFlash::*;
import AuroraImportVC707::*;


interface BlueDBMPlatformIfc;
	method Action readPage(Bit#(64) pageIdx);
	interface PlatformRequest request;
	method Action auroraDbgData(Bit#(32) data);
endinterface

module mkBlueDBMPlatform#(
	FlashControllerIfc flash, 
	BlueDBMHostIfc host, 
	DRAMControllerIfc dram, 
	Vector#(AuroraPorts, AuroraIfc) auroras, 
	Vector#(AuroraIntraPorts, AuroraIfc32) auroraIntras, 
	Vector#(I2C_Count, I2C_User) i2cs
	) (BlueDBMPlatformIfc);
	
	PlatformIndication indication = host.indication;

	FIFO#(Bool) platformStartQ <- mkFIFO();
	Reg#(Bool) platformStarted <- mkReg(False);
	rule platformStart;
		platformStarted <= True;
		platformStartQ.deq;

		//auroras[1].auroraRst.assertReset;
	endrule
	
	/*
	Reg#(Bit#(32)) repeatCount <- mkReg(0);
	Reg#(Bit#(32)) tempHandle <- mkReg(0);
	rule getCommand;
		if ( repeatCount == 0 ) begin
			let cmd <- host.readPage;
			tempHandle <= cmd.handle;
			repeatCount <= 512;//truncate(cmd.pageIdx);
		end else begin
		//if ( cmd.cmd == Cmd_ReadPage ) begin
			flash.command(BlueDBMCommand {
				cmd:Cmd_ReadPage,
				pageIdx:zeroExtend(repeatCount), tag: zeroExtend(repeatCount[5:0]),
				handle:tempHandle
			});
			repeatCount <= repeatCount - 1;
		end
	endrule
	*/

	rule flushI2CResult;
		Bit#(8) response <- i2cs[0].response;
		indication.i2cResult(zeroExtend(response));
	endrule

	Clock aurora_clk = auroras[0].clk;
	Reset aurora_rst = auroras[0].rst;

	AuroraIfc aurora = auroras[0];
	rule driveAuroraRx;
		Bit#(64) data <- aurora.receive;
		//auroraRxQ.enq(data);
		//auroraTQ.deq;
	endrule
/*

	//Reg#(Bit#(8)) txThr <- mkReg(0);

	SyncFIFOIfc#(Bit#(64)) auroraTx <- mkSyncFIFOFromCC(16, aurora_clk);
	Reg#(Bit#(16)) txCount <- mkReg(0);

	rule sendAuroraTx (txCount < 2048 && platformStarted );
		txCount <= txCount + 1;

		//txThr <= 128;

		auroraTx.enq(zeroExtend(txCount));
//		if ( txCount == 2047 ) begin
//			indication.rawWordTest({32'hcafef00d,0});
//		end
		if ( txCount == 32 ) begin
			indication.rawWordTest({32'hcafef00d,1});
		end
	endrule


	//FIFO#(Bool) auroraTQ <- mkSizedFIFO(32, clocked_by aurora_clk, reset_by aurora_rst);
	rule driveAuroraTx;
		auroraTx.deq;
		aurora.send(auroraTx.first);
		//auroraTQ.enq(True);
	endrule

	FIFO#(Bit#(64)) auroraRxQ <- mkSizedFIFO(32, clocked_by aurora_clk, reset_by aurora_rst);
	SyncFIFOIfc#(Bit#(64)) auroraRx <- mkSyncFIFOToCC(32, aurora_clk, aurora_rst);
	Reg#(Bit#(64)) auroraRxCount <- mkReg(0, clocked_by aurora_clk, reset_by aurora_rst);
	
//	(* mutually_exclusive = "driveAuroraTx, driveAuroraRx" *)
	rule driveAuroraRx;
		Bit#(64) data <- aurora.receive;
		auroraRxQ.enq(data);
		//auroraTQ.deq;
	endrule
	rule driveAuroraRx2;// ( auroraRxCount < 16);
		let data = auroraRxQ.first;
		auroraRxQ.deq;

		if ( auroraRxCount != data || data > 2040 ) begin
			auroraRx.enq({auroraRxCount[31:0],data[31:0]});
			auroraRxCount <= data+1;
		end
		else begin
			auroraRxCount <= auroraRxCount + 1;
		end
	endrule
	rule recvAuroraRx;
		auroraRx.deq;

		host.putRawWord(auroraRx.first);
	endrule
	*/

/*
	SyncFIFOIfc#(Bit#(64)) auroraRxQ1 <- mkSyncFIFOToCC(32, auroras[1].clk, auroras[1].rst);
	SyncFIFOIfc#(Bit#(64)) auroraTxQ1 <- mkSyncFIFOFromCC(32, auroras[1].clk);
	Reg#(Bit#(16)) aurora1_0_counter <- mkReg(0);
	rule sendaurora1_0(aurora1_0_counter < 256 && platformStarted);
		auroraTxQ1.enq(zeroExtend(aurora1_0_counter));
		aurora1_0_counter <= aurora1_0_counter + 1;
		
		//host.putRawWord({32'hcafef00d,zeroExtend(aurora1_0_counter)});
	endrule

	//FIFO#(Bool) aurora1Throttle <- mkSizedFIFO(1, clocked_by auroras[1].clk, reset_by auroras[1].rst);
	rule sendaurora1_0f;
		auroraTxQ1.deq;
		auroras[1].send(auroraTxQ1.first);

		//aurora1Throttle.enq(True);
	endrule
	rule dumpAurora1_0;
		let d <- auroras[1].receive;
		if ( d > 250 ) begin
			auroraRxQ1.enq(d);
		end
	
		//aurora1Throttle.deq;
	endrule
	rule flushaurora1_Rx;
		auroraRxQ1.deq;

		indication.rawWordTest({32'hdeadbeef,0,auroraRxQ1.first[15:0]});
	endrule

	rule dumpAurora1_2;
		let d <- auroras[2].receive;
	endrule
	SyncFIFOIfc#(Bit#(64)) auroraTxQ2 <- mkSyncFIFOFromCC(32, auroras[2].clk);
	SyncFIFOIfc#(Bit#(64)) auroraRxQ3 <- mkSyncFIFOToCC(32, auroras[3].clk, auroras[3].rst);
	Reg#(Bit#(16)) aurora1_2_counter <- mkReg(0);
	rule sendaurora1_2(aurora1_2_counter < 60032 && platformStarted);
		auroraTxQ2.enq(zeroExtend(aurora1_2_counter));
		aurora1_2_counter <= aurora1_2_counter + 1;
		
		//host.putRawWord({32'hcafef00d,zeroExtend(aurora1_0_counter)});
	endrule

	//FIFO#(Bool) aurora1Throttle <- mkSizedFIFO(1, clocked_by auroras[1].clk, reset_by auroras[1].rst);
	rule sendaurora1_2f;
		auroraTxQ2.deq;
		auroras[2].send(auroraTxQ2.first);
		//aurora1Throttle.enq(True);
	endrule
	
	rule dumpAurora1_3;
		let d <- auroras[3].receive;
		if ( d > 60000 ) begin
			auroraRxQ3.enq(d);
		end
	
		//aurora1Throttle.deq;
	endrule
	rule flushaurora1_3Rx;
		auroraRxQ3.deq;

		indication.rawWordTest({32'hdeadbeef,0,auroraRxQ3.first[15:0]});
	endrule
*/
	Reg#(Bit#(32)) aurora2_0_counter <- mkReg(0);
	SyncFIFOIfc#(Bit#(32)) aurora2_0_TQ <- mkSyncFIFOFromCC(2, auroraIntras[0].clk);
	rule sendAurora2_0 (aurora2_0_counter < 32 && platformStarted);
		aurora2_0_counter <= aurora2_0_counter + 1;
		aurora2_0_TQ.enq(aurora2_0_counter);
	endrule
	rule sendAurora2_0T;
		aurora2_0_TQ.deq;
		auroraIntras[0].send(aurora2_0_TQ.first);
	endrule
	
	
	Reg#(Bit#(32)) aurora2_0_utr <- mkReg(0, clocked_by auroraIntras[0].clk, reset_by auroraIntras[0].rst);
	SyncFIFOIfc#(Bit#(32)) aurora2_0_ut <- mkSyncFIFOToCC(32, auroraIntras[0].clk, auroraIntras[0].rst);
	rule asagdsfgasdfg ( aurora2_0_utr < 4 );
		aurora2_0_utr <= aurora2_0_utr + 1;
		aurora2_0_ut.enq(aurora2_0_utr);
	endrule
	rule dunomasfasfdg;
		aurora2_0_ut.deq;
		//indication.rawWordTest({32'h12345678,aurora2_0_ut.first});
	endrule

	SyncFIFOIfc#(Bit#(32)) aurora2_0_RQ <- mkSyncFIFOToCC(32, auroraIntras[0].clk, auroraIntras[0].rst);
	rule rxAurora2_0;
		let d <- auroraIntras[0].receive;
		aurora2_0_RQ.enq(d);
	endrule
	rule dumpAurora2_0;
		indication.rawWordTest({32'hf00dbeef,aurora2_0_RQ.first});
		aurora2_0_RQ.deq;
	endrule

	Clock clk <- exposeCurrentClock;
	Reset rst_n <- exposeCurrentReset;
	Clock ddr_clk = dram.ddr_clk;
	Reset ddr_rst_n = dram.ddr_rst_n;

	FlashInterfaceIfc flashInterface <- mkEmulatedFlash(dram, flash);
	
	SyncFIFOIfc#(Bit#(512)) dumpQ <- mkSyncFIFOToCC(2, ddr_clk, ddr_rst_n);
	SyncFIFOIfc#(Bit#(64)) srcQ <- mkSyncFIFOFromCC(2, ddr_clk);
	Reg#(Bit#(64)) dramTestCounter <- mkReg(0, clocked_by ddr_clk, reset_by ddr_rst_n);
	rule getrr;
		Bit#(64) d <- host.getRawWord;
		srcQ.enq(d);
	endrule
	rule writeMem ;
		//Bit#(64) d <- host.getRawWord;
		Bit#(64) d = srcQ.first;
		srcQ.deq;

		Bit#(512) wd = extend({
			dramTestCounter,
			dramTestCounter,
			64'hcafef00db00bd00d,
			dramTestCounter,
			64'hdeadbeef,
			dramTestCounter,
			64'hcafed00d,
			dramTestCounter});
		dram.write(d, wd, 64);
		dramTestCounter <= dramTestCounter + 1;
		//host.putRawWord({32'hcafecafe,dramTestCounter[31:0]});
	endrule
	rule readMem ( dramTestCounter >= 128 && dramTestCounter < 256 );
		dram.readReq((dramTestCounter-128)*64, 64);
		dramTestCounter <= dramTestCounter + 1;
	endrule
	/*
	rule getRead ;
		let dr <- dram.read;
		dumpQ.enq(dr);
	endrule
	*/

	Reg#(Bit#(512)) rdata <- mkReg(0);
	Reg#(Bit#(32)) rcount <- mkReg(0);
	rule flushDump;
		if ( rcount == 0 ) begin
			dumpQ.deq;
			let t = dumpQ.first;
			rdata <= t>>64;
			rcount <= 7;
			host.putRawWord(truncate(t));
		end
		else begin
			rcount <= rcount - 1;
			rdata <= rdata>>64;
			host.putRawWord(truncate(rdata));
		end

		//host.hexdump(tpl_1(t), tpl_2(t));
	endrule

	PageCacheIfc pageCache <- mkPageCache();

	rule getCommand;
		let cmd <- host.getCommand;
		if ( cmd.cmd == Cmd_ReadPage ) begin
			//pageCache.readPage(cmd.pageIdx, truncate(cmd.tag));
			let idx=cmd.pageIdx;
			let page = idx[7:0];
			let block = extend((idx>>8)[13:0]);
			let chip = extend((idx>>(8+14))[1:0]);
			let bus = truncate(idx>>(8+14+2));
			flashInterface.readPage(bus,chip,block,page,truncate(cmd.tag));
		/*
			flash.command(BlueDBMCommand {
				cmd:Cmd_ReadPage,
				pageIdx:cmd.pageIdx, tag:cmd.tag
			});
			*/

			host.writeBackPage(cmd.tag);
		end else 
		if ( cmd.cmd == Cmd_WritePage ) begin
			host.readPage(truncate(cmd.tag));
//			pageCache.writePage(cmd.pageIdx, truncate(cmd.tag));
			let idx=cmd.pageIdx;
			let page = idx[7:0];
			let block = extend((idx>>8)[13:0]);
			let chip = extend((idx>>(8+14))[1:0]);
			let bus = truncate(idx>>(8+14+2));
			flashInterface.writePage(bus,chip,block,page,truncate(cmd.tag));
		end
	endrule

	rule flushRead;
		//let q <- flash.readWord;
		//let q <- pageCache.readWord;
		let q <- flashInterface.readWord;
		// do processing
		// flash.returnPage
		host.writeWord(tpl_1(q), extend(tpl_2(q)));
	endrule

	Reg#(Bit#(64)) counter <- mkReg(0);
	rule flushWrite;
		let q <- host.readWord;
		//pageCache.writeWord(counter, tpl_2(q));
		counter <= counter + 1;
		//pageCache.writeWord(tpl_1(q), tpl_2(q));
		Bit#(8) tag = extend(tpl_2(q)[5:0]);
		flashInterface.writeWord(tpl_1(q), tag);
	endrule

	Reg#(Bit#(1)) channelever <- mkReg(0);
	Reg#(Bit#(1)) laneever <- mkReg(0);
	rule auroraEverUp;
		if ( auroraIntras[0].channel_up == 1 ) channelever <= 1;
		if ( auroraIntras[0].lane_up == 1 ) laneever <= 1;
	endrule

	Reg#(Bit#(32)) lastAuroraDbgData <- mkReg(0);
	FIFO#(Bit#(32)) auroraDbgQ <- mkSizedFIFO(32);
	rule auroraDbgdd( platformStarted );
		let data = auroraDbgQ.first;
		auroraDbgQ.deq;
		indication.rawWordTest({32'hbeefbeef,data});
	endrule

	method Action readPage(Bit#(64) pageIdx);
	endmethod
	method Action auroraDbgData(Bit#(32) data);
		lastAuroraDbgData <= data;
		if ( lastAuroraDbgData != data ) begin
			auroraDbgQ.enq(data);
		end
	endmethod


	interface PlatformRequest request;
		method Action rawWordRequest(Bit#(64) data);
		endmethod
		method Action i2cRequest(Bit#(32) request);
			Bit#(8) datain = request[7:0];
			Bit#(8) addr = request[15:8];
			Bit#(7) slave = request[22:16];
			Bool write = request[23] == 0 ? False : True;

			i2cs[0].request(write, slave, addr, datain);
		endmethod
		method Action start(Bit#(32) dummy);
			platformStartQ.enq(True);
		endmethod
		method Action resetAurora(Bit#(32) dummy);
			//auroras[1].auroraRst.assertReset;
		endmethod
		method Action auroraStatus(Bit#(32) dummy);
			//Bit#(4) aurora0err = {auroras[0].channel_up, auroras[0].lane_up, auroras[0].hard_err, auroras[0].soft_err};
			Bit#(4) aurora0err = 0;//{auroras[0].channel_up, auroras[0].lane_up, auroras[0].hard_err, auroras[0].soft_err};
			//Bit#(4) aurora1err = {auroras[1].channel_up, auroras[1].lane_up, auroras[1].hard_err, auroras[1].soft_err};
			Bit#(4) aurora1err = {auroraIntras[0].channel_up, auroraIntras[0].lane_up, auroraIntras[0].hard_err, auroraIntras[0].soft_err};
			Bit#(4) auroraIntraEver = {0,channelever, laneever};

			indication.rawWordTest({0, auroraIntraEver, aurora0err, aurora1err});
		endmethod
	endinterface
endmodule
