// Copyright (c) 2013 Quanta Research Cambridge, Inc.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import FIFOF::*;
import FIFO::*;
import BRAMFIFO::*;
import BRAM::*;
import GetPut::*;
import ClientServer::*;

import Vector::*;
import List::*;

import PortalMemory::*;
import MemTypes::*;
import MemreadEngine::*;
import MemwriteEngine::*;
import Pipe::*;

import Clocks :: *;
import Xilinx       :: *;
`ifndef BSIM
import XilinxCells ::*;
`endif

import AuroraImportFmc1::*;

import AuroraExtArbiter::*;
import AuroraExtImport::*;
import AuroraExtImport117::*;
import AuroraCommon::*;

import PageCache::*;
import DMABurstHelper::*;
import DRAMImporter::*;
import DRAMArbiter::*;


//typedef TAdd#(8192,128) PageBytes;
typedef 16 WordBytes;
typedef TMul#(8,WordBytes) WordSz;

interface StorageBridgeRequest;
	method Action addBridgeBuffer(Bit#(32) pointer, Bit#(32) offset, Bit#(32) idx);
	method Action readBufferReady(Bit#(32) channel, Bit#(32) bufidx, Bit#(32) targetbuf);
	method Action writeBufferDone(Bit#(32) channel, Bit#(32) bufidx);
endinterface

interface StorageBridgeIndication;
	method Action writePage(Bit#(32) channel, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) bufidx);
	method Action readPage(Bit#(32) channel, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) bufidx, Bit#(32) targetbufidx);
endinterface

interface FlashRequest;
	method Action readPage(Bit#(32) channel, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) bufidx);
	method Action writePage(Bit#(32) channel, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) bufidx);
	method Action erasePage(Bit#(32) channel, Bit#(32) chip, Bit#(32) block);
	method Action sendTest(Bit#(32) data);
	method Action addWriteHostBuffer(Bit#(32) pointer, Bit#(32) offset, Bit#(32) idx);
	method Action addReadHostBuffer(Bit#(32) pointer, Bit#(32) offset, Bit#(32) idx);

	method Action start(Bit#(32) dummy);
	method Action setNetId(Bit#(32) netid);
	method Action setAuroraExtRoutingTable(Bit#(32) node, Bit#(32) portidx, Bit#(32) portsel);
	method Action writeDRAM(Bit#(32) addr, Bit#(32) data1, Bit#(32) data2);
	method Action readDRAM(Bit#(32) addr);

	method Action readRemotePage(Bit#(64) addr, Bit#(32) node);
endinterface

interface FlashIndication;
	method Action readDone(Bit#(32) rbuf);
	method Action writeDone(Bit#(32) tag);
	method Action reqFlashCmd(Bit#(32) inq, Bit#(32) count);
	method Action hexDump(Bit#(32) data);
endinterface

// NumDmaChannels each for flash i/o and emualted i/o
//typedef TAdd#(NumDmaChannels, NumDmaChannels) NumObjectClients;
typedef NumDmaChannels NumObjectClients;

interface MainIfc;
	interface FlashRequest request;
	interface StorageBridgeRequest bridgeRequest;
	interface Vector#(NumObjectClients, ObjectReadClient#(WordSz)) dmaReadClient;
	interface Vector#(NumObjectClients, ObjectWriteClient#(WordSz)) dmaWriteClient;
	//interface ObjectReadClient#(WordSz) dmaReadClient;
	//interface ObjectWriteClient#(WordSz) dmaWriteClient;

	interface Aurora_Pins#(4) aurora_fmc1;
	interface Aurora_Clock_Pins aurora_clk_fmc1;

	interface Vector#(AuroraExtCount, Aurora_Pins#(1)) aurora_ext;
	interface Aurora_Clock_Pins aurora_quad119;
	interface Aurora_Clock_Pins aurora_quad117;
endinterface

typedef enum {Flash, Host, DRAM, PageCache} DataSource deriving (Bits,Eq);

typedef enum {Read,Write,Erase} CmdType deriving (Bits,Eq);
typedef struct { Bit#(5) channel; Bit#(5) chip; Bit#(8) block; Bit#(8) page; CmdType cmd; Bit#(8) tag; Bit#(8) bufidx;} FlashCmd deriving (Bits,Eq);

module mkMain#(FlashIndication indication, StorageBridgeIndication bridge_indication
	, DRAM_User dram_user
	, Clock clk250, Reset rst250)(MainIfc);

	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	//Reset rst200 <- mkAsyncReset( 1, curRst, clk200 );
	
	Integer pageBytes = valueOf(PageBytes);
	Integer wordBytes = valueOf(WordBytes); 
	Integer pageWords = pageBytes/wordBytes;

	Integer numDmaChannels = valueOf(NumDmaChannels);

	Reg#(Bool) started <- mkReg(False);

	GtxClockImportIfc gtx_clk_fmc1 <- mkGtxClockImport;
	AuroraIfc auroraIntra1 <- mkAuroraIntra(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
	/*
   
	Reg#(Bit#(32)) auroraTestIdx <- mkReg(0);
	rule sendAuroraTest(auroraTestIdx > 0);
		auroraIntra1.send(zeroExtend(auroraTestIdx), 7);
		
		auroraTestIdx <= auroraTestIdx - 1;
	endrule
	FIFO#(Bit#(32)) dataQ <- mkSizedFIFO(32);
	rule recvTestData;
		let datao <- auroraIntra1.receive;
		let data = tpl_1(datao);
		let ptype = tpl_2(datao);

		dataQ.enq({2'b0,ptype,data[23:0]});
	endrule

	Reg#(Bit#(32)) auroraDataCheck <- mkReg(0);
	rule dumpD;
		dataQ.deq;
		let data = dataQ.first;
		auroraDataCheck <= data;

		if ( auroraDataCheck - 1 != data )
			indication.hexDump(truncate(data));
		else if ( data[15:0] == 0 ) 
			indication.hexDump(truncate(data));
	endrule
*/
	Reg#(Bit#(HeaderFieldSz)) myNetIdx <- mkReg(1);

`ifndef BSIM
	ClockDividerIfc auroraExtClockDiv5 <- mkDCMClockDivider(5, 4, clocked_by clk250);
	Clock clk50 = auroraExtClockDiv5.slowClock;
`else
	Clock clk50 = curClk;
`endif

	GtxClockImportIfc gtx_clk_119 <- mkGtxClockImport;
	GtxClockImportIfc gtx_clk_117 <- mkGtxClockImport;
	AuroraExtIfc auroraExt119 <- mkAuroraExt(gtx_clk_119.gtx_clk_p_ifc, gtx_clk_119.gtx_clk_n_ifc, clk50);
	AuroraExtIfc auroraExt117 <- mkAuroraExt117(gtx_clk_117.gtx_clk_p_ifc, gtx_clk_117.gtx_clk_n_ifc, clk50);

	AuroraEndpointIfc#(Bit#(32)) aend1 <- mkAuroraEndpoint(0, myNetIdx);
	AuroraEndpointIfc#(Bit#(64)) aend2 <- mkAuroraEndpoint(1, myNetIdx);
	AuroraEndpointIfc#(Bit#(64)) aend3 <- mkAuroraEndpoint(2, myNetIdx);
	//let alist1 = nil;
	let alist1 = cons(aend1.cmd, nil);
	let alist2 = cons(aend2.cmd, alist1);
	let alist3 = cons(aend3.cmd, alist2);

	AuroraExtArbiterIfc auroraExtArbiter <- mkAuroraExtArbiter(
		append(auroraExt119.user, auroraExt117.user)
		, alist3, myNetIdx);

	Reg#(Bit#(64)) auroraTestIdx <- mkReg(0);
	/*
	rule sendAuroraTest(auroraTestIdx > 0);

		if ( myNetIdx == 1 ) begin
			aend1.user.send(truncate(auroraTestIdx), 1);
			aend2.user.send((~64'h0 - auroraTestIdx), 0);
			aend3.user.send((~64'h0 - auroraTestIdx), 1);
		end else begin
			aend1.user.send(truncate(auroraTestIdx), 0);
			aend2.user.send((~64'h0 - auroraTestIdx), 1);
			aend3.user.send((~64'h0 - auroraTestIdx), 0);
		end
		
		auroraTestIdx <= auroraTestIdx - 1;
	endrule
	*/
	FIFO#(Bit#(32)) dataQ <- mkSizedFIFO(32);

	Reg#(Bit#(32)) auroraLatCounter <- mkReg(0);
	FIFO#(Bit#(32)) auroraSendTime <- mkSizedFIFO(64);
	rule countup;
		auroraLatCounter <= auroraLatCounter + 1;
	endrule
	rule recvTestData;
		let rst <- aend1.user.receive;
		let data = tpl_1(rst);
		let src = tpl_2(rst);
		//let data <- auroraExt.user[0].receive;
		if ( myNetIdx == 1 ) begin
			//dataQ.enq({8'haa,data[23:0]});
			auroraSendTime.deq;
			let sendT = auroraSendTime.first;
			indication.hexDump(auroraLatCounter-sendT);
		end
		else begin
			aend1.user.send(data,src);
			indication.hexDump(zeroExtend(src));
		end

		//if ( data[17:0] == 0 )
		//dataQ.enq({8'haa,data[23:0]});
	endrule
	rule recvTestData2;
		let rst <- aend2.user.receive;
		let data = tpl_1(rst);

		if ( data[17:0] == 0 )
		dataQ.enq({8'hcc,data[23:0]});
	endrule
	
	rule recvTestData3;
		let rst <- aend3.user.receive;
		let data = tpl_1(rst);
		//let data <- auroraExt.user[2].receive;

		//dataQ.enq(truncate(data));
		if ( data[17:0] == 0 )
		dataQ.enq({8'hbb,data[23:0]});
	endrule

	Reg#(Bit#(32)) auroraDataCheck <- mkReg(0);
	rule dumpD;
		dataQ.deq;
		let data = dataQ.first;
		auroraDataCheck <= auroraDataCheck + 1;
		//auroraDataCheck <= data;
		//if ( auroraDataCheck - 1 != data )
		//	indication.hexDump({8'haa,truncate(data)});
		//else
			indication.hexDump({4'hb,truncate(data)});
	endrule


// Aurora Example done /////////////////////////////////////


// DRAM access start ///////////////////////////////////////
   
	DRAMEndpointIfc memuser1 <- mkDRAMUser;
	DRAMEndpointIfc memuser2 <- mkDRAMUser;
	DRAMEndpointIfc memuser3 <- mkDRAMUser;
	let list1 = cons(memuser1.cmd, nil);
	let list2 = cons(memuser2.cmd, list1);
	let list3 = cons(memuser3.cmd, list2);
	DRAMArbiterIfc dramArbiter <- mkDRAMArbiter(dram_user,list3);

	Reg#(Bit#(32)) dramTestIdx <- mkReg(0);
	rule writeMem ( dramTestIdx < 8*1024  && started);
		dramTestIdx <= dramTestIdx + 1;
		DRAM_User user = memuser1.user;
		Bit#(512) wdata = {
		32'hdeadbeef,
		32'h12345678,
		32'h98765432,
		32'hc001d00d,
		32'hcafecafe,
		32'hf00df00d,
		//32'haaaaaaaa,
			dramTestIdx,
			dramTestIdx,
		32'hcccccccc,
			dramTestIdx,
			dramTestIdx,
			dramTestIdx,
			dramTestIdx,
			dramTestIdx,
			dramTestIdx,
			dramTestIdx
		};
		if ( dramTestIdx < 4*1024 ) begin
			user.request(dramTestIdx, wdata, True);
		end else begin
			user.request(dramTestIdx-(4*1024), ?, False);
		end
	endrule
	Reg#(Bit#(8)) readRsp2Cnt <- mkReg(0);
	rule flushDRAMDataRead;
		readRsp2Cnt <= readRsp2Cnt + 1;
		DRAM_User user = memuser1.user;
		let d <- user.read_data;
		//$display ( "read data at 2" );
		//if ( d[6:0] == 0 ) begin
			//indication.hexDump({8'hff, d[23:0]});
		if ( readRsp2Cnt == 0 ) begin
			Bit#(8) a = 8'hff;
			Bit#(8) b = d[7+32+256:256+32];
			Bit#(8) c = d[7+256:256];
			Bit#(8) d = d[7:0];
			
			//indication.hexDump({a,b,c,d});
			//indication.hexDump({8'hff,d[7+8+256:264], d[7+256:256], d[7:0]});
		end
	endrule

	Reg#(Bit#(32)) dramTestIdx2 <- mkReg(0);
	FIFO#(Bool) printThisReqQ1 <- mkSizedFIFO(16);
	rule writeMem1 ( dramTestIdx2 < 1024*8 && started);
		dramTestIdx2 <= dramTestIdx2 + 1;
		DRAM_User user = memuser2.user;
		Bit#(512) wdata = {
		32'hdeadbeef,
		32'h12345678,
		32'h98765432,
		32'hc001d00d,
		32'hcafecafe,
		32'hf00df00d,
		//32'haaaaaaaa,
			dramTestIdx2>>1,
			dramTestIdx2>>1,
		32'hcccccccc,
			dramTestIdx2>>1,
			dramTestIdx2>>1,
			dramTestIdx2>>1,
			dramTestIdx2>>1,
			dramTestIdx2>>1,
			dramTestIdx2>>1,
			dramTestIdx2>>1
		};
		if ( dramTestIdx2[0] == 0 ) begin
			user.request((dramTestIdx2>>1)+1024*10, wdata, True);
		end else begin
			user.request((dramTestIdx2>>1)+1024*10, ?, False);
			if ( (dramTestIdx2>>1)[3:0] == 4'hc ) begin
				printThisReqQ1.enq(True);
			end else begin
				printThisReqQ1.enq(False);
			end
		end
	endrule
	//Reg#(Bit#(8)) readRsp1Cnt <- mkReg(0);
	rule flushDRAMDataRead1;
		//readRsp1Cnt <= readRsp1Cnt + 1;

		printThisReqQ1.deq;

		DRAM_User user = memuser2.user;
		let d <- user.read_data;
		//$display ( "read data at 1" );
		//if ( d[6:0] == 0 ) begin
		//if ( readRsp1Cnt == 0 ) begin
		if ( printThisReqQ1.first == True ) begin
			Bit#(8) a = 8'hee;
			Bit#(8) b = d[7+32:32];
			Bit#(8) c = d[7+256:256];
			Bit#(8) d = d[7:0];
			//indication.hexDump({a,b,c,d});
			//indication.hexDump({8'hee,d[7+8:8], d[7+256:256], d[7:0]});
		end
	endrule
	rule flushDRAM3Read;
		DRAM_User user = memuser3.user;
		let d <- user.read_data;
		Bit#(16) d1 = d[15:0];
		Bit#(16) d2 = d[15+256:256];
		indication.hexDump({d2,d1});
	endrule

// DRAM access end /////////////////////////////////////////




// Host memory access start ////////////////////////////////
	Reg#(DataSource) dataSource <- mkReg(PageCache);
	
	Vector#(NumDmaChannels, MemwriteEngineV#(WordSz,1,2)) weV <- replicateM(mkMemwriteEngineBuff(1024));
	Vector#(NumDmaChannels, MemreadEngineV#(WordSz,1,2))  reV <- replicateM(mkMemreadEngineBuff(1024));
	FIFO#(Bool) dmaReadThrottleQ <- mkSizedFIFO(1); //FIXME

	Vector#(NumDmaChannels, StorageBridgeDmaManagerIfc#(WordSz)) storageBridges;

	Vector#(NumDmaChannels, PageCacheIfc#(1,128)) pageCaches; // FIXME WriteTagCount no longer total number of tags //changed to 128
	for ( Integer wIdx = 0; wIdx < numDmaChannels; wIdx = wIdx + 1 ) begin
		let pageCache <- mkPageCache; 
		pageCaches[wIdx] = pageCache;

		let we = weV[wIdx];
		let re = reV[wIdx];

		storageBridges[wIdx] <- mkStorageBridgeManager(
			we.writeServers[1], we.dataPipes[1],
			re.readServers[1], re.dataPipes[1]);
	end
	

/////////////// DMA Writer with page cache //////////////////////////////////////

	Vector#(NumDmaChannels, DMAWriteEngineIfc#(WordSz)) dmaWriters;
	Vector#(NumDmaChannels, FreeBufferClientIfc) dmaWriterFreeBufferClient;
	//MemwriteEngineV#(WordSz,1,NumDmaChannels) we <- mkMemwriteEngine;
	for ( Integer wIdx = 0; wIdx < numDmaChannels; wIdx = wIdx + 1 ) begin
		let we = weV[wIdx];
		let pageCache = pageCaches[wIdx];
		let storageBridge = storageBridges[wIdx];

		//DMAWriteEngineIfc#(WordSz) dmaWriter <- mkDmaWriteEngine(we.writeServers[wIdx], we.dataPipes[wIdx]);
		DMAWriteEngineIfc#(WordSz) dmaWriter <- mkDmaWriteEngine(we.writeServers[0], we.dataPipes[0]);
		dmaWriters[wIdx] = dmaWriter;

		rule dmaWriteData;
			if ( dataSource == PageCache ) begin
				let r <- pageCache.readWord;
				let d = tpl_1(r);
				let t = tpl_2(r);
				dmaWriter.write(d,t);
			end
			else if ( dataSource == Host ) begin
				let r <- storageBridge.readWord;
				let d = tpl_1(r);
				let t = tpl_2(r);
				dmaWriter.write(d,t);

				//$display ( "reading data %x with tag %d", d,t );
			end
		endrule

		dmaWriterFreeBufferClient[wIdx] = dmaWriter.bufClient;
	end
	FreeBufferManagerIfc writeBufMan <- mkFreeBufferManager(dmaWriterFreeBufferClient);

	//Reg#(Bit#(4)) readDoneCounter <- mkReg(0);
	//Reg#(Bit#(32)) rbufBuff <- mkReg(0);
	//Reg#(Bit#(32)) tagBuff <- mkReg(0);

	FIFO#(Bit#(8)) writeDoneIndicationQ <- mkFIFO;
	rule dmaWriteDoneCheck;
			let r <- writeBufMan.done;
			writeDoneIndicationQ.enq(r);
			dmaReadThrottleQ.deq;
			$display( "write page done in %d", r );
	endrule
	rule flushDmaWriteDone;
		let r = writeDoneIndicationQ.first;
		writeDoneIndicationQ.deq;
		indication.readDone(zeroExtend(r));
		$display ( "sending write page done indication %d",r);

	endrule
/////////////////////////////////////////////////////////////////////////////////////


	Vector#(NumDmaChannels, DMAReadEngineIfc#(WordSz)) dmaReaders;
	//MemreadEngineV#(WordSz,1, NumDmaChannels)  re <- mkMemreadEngine;
	FIFO#(Bit#(8)) dmaReadDoneQ <- mkFIFO;
	rule driveDmaReadDone;
		let bufidx = dmaReadDoneQ.first;
		dmaReadDoneQ.deq;
		indication.writeDone(zeroExtend(bufidx));

		if ( dataSource == Host ) dmaReadThrottleQ.deq;
	endrule
	
	Vector#(NumDmaChannels, FIFO#(FlashCmd)) storageBridgeWritingQs <- replicateM(mkSizedFIFO(4));

	for ( Integer rIdx = 0; rIdx < numDmaChannels; rIdx = rIdx + 1 ) begin
		let re = reV[rIdx];
		let pageCache = pageCaches[rIdx];
		let storageBridge = storageBridges[rIdx];

		DMAReadEngineIfc#(WordSz) dmaReader <- mkDmaReadEngine(re.readServers[0], re.dataPipes[0]);
		//DMAReadEngineIfc#(WordSz) dmaReader <- mkDmaReadEngine(re.readServers[rIdx], re.dataPipes[rIdx]);
		dmaReaders[rIdx] = dmaReader;

		rule dmaReadDone;
			let bufidx <- dmaReader.done;
			dmaReadDoneQ.enq(bufidx);
		endrule
		rule dmaReadData;
			if ( dataSource == PageCache ) begin
				let r <- dmaReader.read;
				let d = tpl_1(r);
				let t = tpl_2(r);
				pageCache.writeWord(d,t);
			end
			else if ( dataSource == Host ) begin
				let r <- dmaReader.read;
				let d = tpl_1(r);
				let t = tpl_2(r);
				storageBridge.writeWord(d);//,t);
			end
			//$display( "writing to pagecache %x %d", d, t );
		endrule
		rule flushBridgeWriteDone;
			let bufidx <- storageBridge.writeDone;
			
			let cmd = storageBridgeWritingQs[rIdx].first;
			storageBridgeWritingQs[rIdx].deq;

			bridge_indication.writePage(
				zeroExtend(cmd.channel), zeroExtend(cmd.chip), 
				zeroExtend(cmd.block), zeroExtend(cmd.page),
				zeroExtend(bufidx));
		endrule
	end // for loop



	Reg#(Bit#(32)) curReqsInQ <- mkReg(0);
	Reg#(Bit#(32)) numReqsRequested <- mkReg(0);
	rule driveNewReqs(started&& curReqsInQ + numReqsRequested < 128-48 );
		numReqsRequested <= numReqsRequested + 32;
		indication.reqFlashCmd(curReqsInQ, 32);
		//$display( "Requesting more flash commands" );
	endrule

	FIFO#(Bool) bridgeReadPageThrottleQ <- mkSizedFIFO(1);//FIXME

	FIFO#(FlashCmd) flashCmdQ <- mkSizedFIFO(128);
	rule driveFlashCmd (started);
		let cmd = flashCmdQ.first;
		
		if ( cmd.cmd == Read ) begin
			curReqsInQ <= curReqsInQ -1;

			flashCmdQ.deq;

			// temporary stuff
			let dmaWriter = dmaWriters[cmd.channel];
			let pageCache = pageCaches[cmd.channel];
			let storageBridge = storageBridges[cmd.channel];

			dmaWriter.startWrite(cmd.bufidx, fromInteger(pageWords));

			if ( dataSource == PageCache ) begin
				pageCache.readPage( zeroExtend(cmd.page), cmd.bufidx);
			end
			else if ( dataSource == Host ) begin
				let bufidx <- storageBridge.getFreeBufIdx;
				//storageBridge.readPage (cmd);

				bridgeReadPageThrottleQ.enq(True);
				bridge_indication.readPage(
					zeroExtend(cmd.channel), zeroExtend(cmd.chip), 
					zeroExtend(cmd.block), zeroExtend(cmd.page),
					zeroExtend(bufidx), zeroExtend(cmd.bufidx));
			end
			$display( "starting page read %d at tag %d in buffer %d", cmd.page, cmd.tag, cmd.bufidx );

			dmaReadThrottleQ.enq(False);
		end else if ( cmd.cmd == Write ) begin
			curReqsInQ <= curReqsInQ -1;

			flashCmdQ.deq;

			let dmaReader = dmaReaders[cmd.channel];
			let pageCache = pageCaches[cmd.channel];
			let storageBridge = storageBridges[cmd.channel];

			dmaReader.startRead(cmd.bufidx, fromInteger(pageWords));

			if ( dataSource == PageCache ) begin
				pageCache.writePage(zeroExtend(cmd.page), cmd.bufidx);
			end
			else if ( dataSource == Host ) begin
				let bufidx <- storageBridge.getFreeBufIdx;
				storageBridge.writePage(bufidx);
				storageBridgeWritingQs[cmd.channel].enq(cmd);
			end
			//bridge_indication.writePage(zeroExtend(cmd.page), zeroExtend(cmd.bufidx));
			$display( "starting page write page %d at tag %d", cmd.page, cmd.bufidx );

			if ( dataSource == Host ) dmaReadThrottleQ.enq(True);
		end
	endrule

   
	Vector#(NumObjectClients, ObjectReadClient#(WordSz)) dmaReadClients;
	Vector#(NumObjectClients, ObjectWriteClient#(WordSz)) dmaWriteClients;
	for ( Integer idx = 0; idx < numDmaChannels; idx = idx + 1 ) begin
		dmaReadClients[idx] = reV[idx].dmaClient;
		dmaWriteClients[idx] = weV[idx].dmaClient;
	end
	/*
	for ( Integer idx = 0; idx < numDmaChannels; idx = idx + 1 ) begin
		let iidx = idx + numDmaChannels;
		dmaReadClients[iidx] = reV[idx].dmaClient;
		dmaWriteClients[iidx] = weV[idx].dmaClient;
	end
	*/

   interface FlashRequest request;
	method Action readPage(Bit#(32) channel, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) bufidx);

		CmdType cmd = Read;
		FlashCmd fcmd = FlashCmd{
			channel: truncate(channel),
			chip: truncate(chip),
			block: truncate(block),
			page: truncate(page),
			cmd: cmd,
			bufidx: truncate(bufidx),
			tag: ?};

		flashCmdQ.enq(fcmd);
		curReqsInQ <= curReqsInQ +1;
		numReqsRequested <= numReqsRequested - 1;

			
	endmethod
   method Action writePage(Bit#(32) channel, Bit#(32) chip, Bit#(32) block, Bit#(32) page, Bit#(32) bufidx);
		CmdType cmd = Write;
		FlashCmd fcmd = FlashCmd{
			channel: truncate(channel),
			chip: truncate(chip),
			block: truncate(block),
			page: truncate(page),
			cmd: cmd,
			bufidx: truncate(bufidx),
			tag: ?};

		flashCmdQ.enq(fcmd);
		curReqsInQ <= curReqsInQ +1;
		numReqsRequested <= numReqsRequested - 1;
	endmethod
	method Action erasePage(Bit#(32) channel, Bit#(32) chip, Bit#(32) block);
		CmdType cmd = Erase;
		FlashCmd fcmd = FlashCmd{
			channel: truncate(channel),
			chip: truncate(chip),
			block: truncate(block),
			page: 0,
			cmd: cmd,
			tag: 0};

		flashCmdQ.enq(fcmd);
		curReqsInQ <= curReqsInQ +1;
		numReqsRequested <= numReqsRequested - 1;
	endmethod
	method Action sendTest(Bit#(32) data);
		auroraTestIdx <= zeroExtend(data);
		if ( myNetIdx == 1 ) begin
			aend1.user.send(zeroExtend(data), truncate(data));
			auroraSendTime.enq(auroraLatCounter);
		end
	endmethod
	method Action setAuroraExtRoutingTable(Bit#(32) node, Bit#(32) portidx, Bit#(32) portsel);
		auroraExtArbiter.setRoutingTable(truncate(node), truncate(portidx), truncate(portsel));
	endmethod
	method Action writeDRAM(Bit#(32) addr, Bit#(32) data1, Bit#(32) data2);
		Bit#(256) d1 = zeroExtend(data1);
		Bit#(256) d2 = zeroExtend(data2);
		memuser3.user.request(addr, {d1,d2}, True);
		//let addrs = addr<<3;
		//Bit#(64) mask = ~64'h0;
		//dram_user.request(addr, {d1,d2}, True);
		//wcmdQ.enq(tuple2(addrs, {d1,d2}));
		//dram_user.request(truncate(addrs), mask, {d1,d2});
	endmethod
	method Action readDRAM(Bit#(32) addr);
		//memuser3.user.readReq(addr);
		//let addrs = addr<<3;
		//dram_user.request(truncate(addrs), 0, 0);
		//rcmdQ.enq(addrs);
		//dram_user.request(addr, ?, False);
		memuser3.user.request(addr, ?, False);
	endmethod
	method Action readRemotePage(Bit#(64) addr, Bit#(32) node);
		if ( node == myNetIdx ) begin
		end else begin
			aend2.user.send(addr,truncate(node));
		end
	endmethod
	method Action addWriteHostBuffer(Bit#(32) pointer, Bit#(32) offset, Bit#(32) idx);
		for (Integer i = 0; i < numDmaChannels; i = i + 1) begin
			dmaReaders[i].addBuffer(truncate(idx), offset, pointer);
		end
	endmethod
	method Action addReadHostBuffer(Bit#(32) pointer, Bit#(32) offset, Bit#(32) idx);
		writeBufMan.addBuffer(offset, pointer);
	endmethod
	method Action start(Bit#(32) datasource);
		if ( datasource == 0 ) begin
			dataSource <= PageCache;
		end else begin
			dataSource <= Host;
		end

		indication.hexDump({8'hcc,0,

			auroraExt117.user[3].lane_up,
			auroraExt117.user[3].channel_up,
			auroraExt117.user[2].lane_up,
			auroraExt117.user[2].channel_up,
			auroraExt117.user[1].lane_up,
			auroraExt117.user[1].channel_up,
			auroraExt117.user[0].lane_up,
			auroraExt117.user[0].channel_up,
			
			auroraExt119.user[3].lane_up,
			auroraExt119.user[3].channel_up,
			auroraExt119.user[2].lane_up,
			auroraExt119.user[2].channel_up,
			auroraExt119.user[1].lane_up,
			auroraExt119.user[1].channel_up,
			auroraExt119.user[0].lane_up,
			auroraExt119.user[0].channel_up
			});
		started <= True;
	endmethod
	method Action setNetId(Bit#(32) netid);
		myNetIdx <= truncate(netid);
	endmethod
	endinterface

	interface StorageBridgeRequest bridgeRequest;
		method Action addBridgeBuffer(Bit#(32) pointer, Bit#(32) offset, Bit#(32) idx);
			//FIXME this interleaves buffers... :(
			Bit#(2) channel = truncate(idx>>5);
			Bit#(8) bufidx = zeroExtend(idx[4:0]);
			storageBridges[channel].addBridgeBuffer(pointer, offset, bufidx);
		endmethod
		method Action readBufferReady(Bit#(32) channel, Bit#(32) bufidx, Bit#(32) targetbuf);
			bridgeReadPageThrottleQ.deq;
			storageBridges[channel].readBufferReady(truncate(bufidx), truncate(targetbuf));
			$display( "read buffer ready %d %d", channel, bufidx );
		endmethod
		method Action writeBufferDone(Bit#(32) channel, Bit#(32) bufidx);
			storageBridges[channel].returnFreeBufIdx(truncate(bufidx));
			$display( "returning storageBridges buffer %d @ %d", bufidx, channel );
		endmethod
	endinterface

   //interface ObjectReadClient dmaReadClient = re.dmaClient;
   //interface ObjectWriteClient dmaWriteClient = we.dmaClient;
   interface ObjectReadClient dmaReadClient = dmaReadClients;
   interface ObjectWriteClient dmaWriteClient = dmaWriteClients;

   interface Aurora_Pins aurora_fmc1 = auroraIntra1.aurora;
   interface Aurora_Clock_Pins aurora_clk_fmc1 = gtx_clk_fmc1.aurora_clk;

	interface Aurora_Pins aurora_ext = append(auroraExt119.aurora, auroraExt117.aurora);
	interface Aurora_Clock_Pins aurora_quad119 = gtx_clk_119.aurora_clk;
	interface Aurora_Clock_Pins aurora_quad117 = gtx_clk_117.aurora_clk;
endmodule

