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

import PortalMemory::*;
import MemTypes::*;
import MemreadEngine::*;
import MemwriteEngine::*;
import Pipe::*;

import AuroraImportFmc1::*;
import AuroraExtImport::*;
import AuroraCommon::*;

import PageCache::*;
import DMABurstHelper::*;


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
endinterface

typedef enum {Flash, Host, DRAM, PageCache} DataSource deriving (Bits,Eq);

typedef enum {Read,Write,Erase} CmdType deriving (Bits,Eq);
typedef struct { Bit#(5) channel; Bit#(5) chip; Bit#(8) block; Bit#(8) page; CmdType cmd; Bit#(8) tag; Bit#(8) bufidx;} FlashCmd deriving (Bits,Eq);

module mkMain#(FlashIndication indication, StorageBridgeIndication bridge_indication
	, Clock clk250, Reset rst250)(MainIfc);
	
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
	GtxClockImportIfc gtx_clk_119 <- mkGtxClockImport;
	AuroraExtIfc auroraExt <- mkAuroraExt(gtx_clk_119.gtx_clk_p_ifc, gtx_clk_119.gtx_clk_n_ifc, clk250);
	Reg#(Bit#(32)) auroraTestIdx <- mkReg(0);
	rule sendAuroraTest(auroraTestIdx > 0);
		auroraExt.user[1].send({1,auroraTestIdx[30:0]});
		auroraExt.user[3].send({0,auroraTestIdx[30:0]});
		
		auroraTestIdx <= auroraTestIdx - 1;
	endrule
	FIFO#(Bit#(32)) dataQ <- mkSizedFIFO(32);
	rule recvTestData;
		let data <- auroraExt.user[0].receive;

		dataQ.enq(truncate(data));
	endrule
	
	rule recvTestData3;
		let data <- auroraExt.user[2].receive;

		dataQ.enq(truncate(data));
	endrule

	Reg#(Bit#(32)) auroraDataCheck <- mkReg(0);
	rule dumpD;
		dataQ.deq;
		let data = dataQ.first;
		auroraDataCheck <= data;

/*
		if ( auroraDataCheck - 1 != data )
			indication.hexDump(truncate(data));
		else */
		if ( data[17:0] == 0 ) 
			indication.hexDump(truncate(data));
	endrule
	
	Vector#(NumDmaChannels, MemwriteEngineV#(WordSz,1,2)) weV <- replicateM(mkMemwriteEngine);
	Vector#(NumDmaChannels, MemreadEngineV#(WordSz,1,2))  reV <- replicateM(mkMemreadEngine);
	FIFO#(Bool) dmaReadThrottleQ <- mkSizedFIFO(1); //FIXME

	Vector#(NumDmaChannels, StorageBridgeDmaManagerIfc#(WordSz)) storageBridges;

	Vector#(NumDmaChannels, PageCacheIfc#(2,128)) pageCaches; // FIXME WriteTagCount no longer total number of tags //changed to 128
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
	Reg#(DataSource) dataSource <- mkReg(PageCache);

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

		dmaReadThrottleQ.deq;
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

			dmaReadThrottleQ.enq(True);
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
		auroraTestIdx <= data;
	endmethod
	method Action addWriteHostBuffer(Bit#(32) pointer, Bit#(32) offset, Bit#(32) idx);
		for (Integer i = 0; i < numDmaChannels; i = i + 1) begin
			dmaReaders[i].addBuffer(truncate(idx), offset, pointer);
		end
	endmethod
	method Action addReadHostBuffer(Bit#(32) pointer, Bit#(32) offset, Bit#(32) idx);
		writeBufMan.addBuffer(truncate(offset), pointer);
	endmethod
	method Action start(Bit#(32) datasource);
		if ( datasource == 0 ) begin
			dataSource <= PageCache;
		end else begin
			dataSource <= Host;
		end

		indication.hexDump({8'hcc,0,
			auroraExt.user[0].lane_up,
			auroraExt.user[0].channel_up,
			auroraExt.user[1].lane_up,
			auroraExt.user[1].channel_up,
			auroraExt.user[2].lane_up,
			auroraExt.user[2].channel_up,
			auroraExt.user[3].lane_up,
			auroraExt.user[3].channel_up
			});
		started <= True;
	endmethod
	endinterface

	interface StorageBridgeRequest bridgeRequest;
		method Action addBridgeBuffer(Bit#(32) pointer, Bit#(32) offset, Bit#(32) idx);
			//FIXME this interleaves buffers... :(
			Bit#(2) channel = truncate(idx>>5);
			Bit#(8) bufidx = zeroExtend(idx[4:0]);
			storageBridges[channel].addBridgeBuffer(pointer, truncate(offset), bufidx);
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

	interface Aurora_Pins aurora_ext = auroraExt.aurora;
	interface Aurora_Clock_Pins aurora_quad119 = gtx_clk_119.aurora_clk;
endmodule

