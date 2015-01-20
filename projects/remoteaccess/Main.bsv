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

import ControllerTypes::*;
import FlashCtrlVirtex::*;
import FlashCtrlModel::*;

import AuroraExtArbiter::*;
import AuroraExtImport::*;
import AuroraExtImport117::*;
import AuroraCommon::*;

import DRAMImporter::*;
import DRAMArbiter::*;

import StreamingSerDes::*;


typedef 8 WordBytes;
typedef TMul#(8,WordBytes) WordSz;

interface GeneralRequest;
	method Action setAuroraExtRoutingTable(Bit#(32) node, Bit#(32) portidx, Bit#(32) portsel);
	method Action setNetId(Bit#(32) netid);
	method Action start(Bit#(32) dummy);

	method Action readRemotePage(Bit#(64) addr, Bit#(32) node, Bit#(32) source, Bit#(32) tag);
	method Action readPageDone(Bit#(32) sketch);
	method Action sendDMAPage(Bit#(32) rdref, Bit#(32) dst);
	method Action setDebugVals (Bit#(32) flag, Bit#(32) debugDelay); 

endinterface

interface GeneralIndication;
	method Action readPage(Bit#(64) addr, Bit#(32) dstnod, Bit#(32) datasource);
	method Action recvSketch(Bit#(32) sketch, Bit#(32) latency);
	method Action hexDump(Bit#(32) hex);
	method Action timeDiffDump(Bit#(32) diff, Bit#(32) ttype);
endinterface

// NumDmaChannels each for flash i/o and emualted i/o
//typedef TAdd#(NumDmaChannels, NumDmaChannels) NumObjectClients;
//typedef NumDmaChannels NumObjectClients;

interface MainIfc;
	interface GeneralRequest request;
	interface ObjectReadClient#(WordSz) dmaReadClient;
	interface ObjectWriteClient#(WordSz) dmaWriteClient;

	interface Aurora_Pins#(4) aurora_fmc1;
	interface Aurora_Clock_Pins aurora_clk_fmc1;

	interface Vector#(AuroraExtCount, Aurora_Pins#(1)) aurora_ext;
	interface Aurora_Clock_Pins aurora_quad119;
	interface Aurora_Clock_Pins aurora_quad117;
endinterface

typedef enum {Flash, Host, DRAM, PageCache} DataSource deriving (Bits,Eq);

typedef enum {Read,Write,Erase} CmdType deriving (Bits,Eq);
//typedef struct { Bit#(5) channel; Bit#(5) chip; Bit#(8) block; Bit#(8) page; CmdType cmd; Bit#(8) tag; Bit#(8) bufidx;} FlashCmd deriving (Bits,Eq);

module mkMain#(GeneralIndication indication
	, DRAM_User dram_user
	, Clock clk250, Reset rst250)(MainIfc);

	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	//Reset rst200 <- mkAsyncReset( 1, curRst, clk200 );
	
	//Integer pageBytes = valueOf(PageBytes);
	//Integer wordBytes = valueOf(WordBytes); 
	//Integer pageWords = pageBytes/wordBytes;

	//Integer numDmaChannels = valueOf(NumDmaChannels);

	Reg#(Bool) started <- mkReg(False);
	Reg#(Bit#(HeaderFieldSz)) myNetIdx <- mkReg(1);

	GtxClockImportIfc gtx_clk_fmc1 <- mkGtxClockImport;
	//AuroraIfc auroraIntra1 <- mkAuroraIntra(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
	`ifdef BSIM
		FlashCtrlVirtexIfc flashCtrl <- mkFlashCtrlModel(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
	`else
		FlashCtrlVirtexIfc flashCtrl <- mkFlashCtrlVirtex(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
	`endif

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

	MemwriteEngineV#(WordSz,1,4) we <- mkMemwriteEngineBuff(512);
	MemreadEngineV#(WordSz,1,4)  re <- mkMemreadEngineBuff(512);















	AuroraEndpointIfc#(Bit#(32)) aend1 <- mkAuroraEndpoint(0, myNetIdx);
	AuroraEndpointIfc#(Tuple3#(Bit#(64), Bit#(8), Bit#(8))) aend2 <- mkAuroraEndpoint(1, myNetIdx);
	AuroraEndpointIfc#(Bit#(32)) aend3 <- mkAuroraEndpoint(2, myNetIdx);
	AuroraEndpointIfc#(Tuple2#(Bit#(105),Bool)) aendData1 <- mkAuroraEndpoint(3, myNetIdx);
	AuroraEndpointIfc#(Tuple2#(Bit#(105),Bool)) aendData2 <- mkAuroraEndpoint(4, myNetIdx);







	//let alist1 = nil;
	let alist1 = cons(aend1.cmd, nil);
	let alist2 = cons(aend2.cmd, alist1);
	let alist3 = cons(aend3.cmd, alist2);
	let alist4 = cons(aendData2.cmd, cons(aendData1.cmd, alist3));
	Vector#(2,StreamingSerializerIfc#(Bit#(128), Bit#(105))) ser <- replicateM(mkStreamingSerializer);
	Vector#(2,StreamingDeserializerIfc#(Bit#(105), Bit#(128))) des <- replicateM(mkStreamingDeserializer);

	let auroraList = alist4;
	AuroraExtArbiterIfc auroraExtArbiter <- mkAuroraExtArbiter(
		append(auroraExt119.user, auroraExt117.user)
		, auroraList, myNetIdx);
	
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
	endrule

	Reg#(Bit#(32)) latencyCounter <- mkReg(0);
	rule incLatencyCounter;
		latencyCounter <= latencyCounter + 1;
	endrule

	FIFO#(Bit#(32)) readReqTimestampQ <- mkSizedFIFO(64);
	FIFO#(Bit#(6)) readReqSrcQ <- mkSizedFIFO(64);
	
	FIFO#(FlashCmd) flashCmdQ <- mkSizedFIFO(32);
	
	rule driveFlashCmd /*(started)*/;
		let cmd = flashCmdQ.first;
		flashCmdQ.deq;
		flashCtrl.user.sendCmd(cmd); //forward cmd to flash ctrl
	endrule
	//Handle write data requests from controller
	Reg#(Bit#(6)) curDataDst <- mkReg(0);
	rule handleWriteDataRequestFromFlash;
		TagT tag <- flashCtrl.user.writeDataReq();
		readReqSrcQ.deq;
		curDataDst <= readReqSrcQ.first;

		//check which bus it's from
		//let bus = tag2busTable[tag];
		//wrToDmaReqQ.enq(tuple2(tag, bus));
	endrule
	Reg#(Bit#(1)) auroraLaneIdx <- mkReg(0);
	Reg#(Bit#(32)) delayRegSet <- mkReg(0);
	Reg#(Bit#(32)) delayReg <- mkReg(0);
	rule doEnqReadFromFlash;
		if (delayReg==0) begin
			let taggedRdata <- flashCtrl.user.readWord();
			auroraLaneIdx <= auroraLaneIdx + 1;

			delayReg <= delayRegSet;
			
			ser[auroraLaneIdx].enq(tpl_1(taggedRdata));
		end
		else begin
			delayReg <= delayReg - 1;
		end
	endrule
	rule flushD1;
		let d <- ser[0].deq;
		aendData1.user.send(d,curDataDst);
	endrule
	rule flushD2;
		let d <- ser[1].deq;
		aendData2.user.send(d,curDataDst);
	endrule

	rule recvD1;
		let d <- aendData1.user.receive;
		let data = tpl_1(d);
		des[0].enq(tpl_1(data), tpl_2(data));
	endrule
	rule recvD2;
		let d <- aendData2.user.receive;
		let data = tpl_1(d);
		des[1].enq(tpl_1(data), tpl_2(data));
	endrule

	Reg#(Bit#(32)) dataRecvCount <- mkReg(0);
	Reg#(Bit#(1)) desIdx <- mkReg(0);
	rule flushDes;
		desIdx <= desIdx + 1;
		let d <- des[desIdx].deq;
		$display( "data: %x", d );
		if ( dataRecvCount+1 >= 512 ) begin
			dataRecvCount <= 0;
			readReqTimestampQ.deq;
			Bit#(32) elapsed = latencyCounter - readReqTimestampQ.first;

			indication.timeDiffDump(elapsed, 3);
		end
		else begin
			dataRecvCount <= dataRecvCount + 1;
		end
	endrule

	FIFO#(Bit#(32)) hostReqTimestampQ <- mkSizedFIFO(8);
	FIFO#(Bit#(32)) hostDmaTimestampQ <- mkSizedFIFO(8);
	rule recvTestData2;
		let rst <- aend2.user.receive;
		let data = tpl_1(rst);
		let src = tpl_2(rst);
		let addr = tpl_1(data);
		let datasource = tpl_2(data);
		let tag = tpl_3(data);

		let page = (addr);
		let block = (addr>>6);
		let chip = (addr>>10);
		let bus = (addr>>13);
		
		curDataDst <= src;
		//indication.hexDump({8'hbb, 0, src});

		if ( datasource == 0 ) begin
			readReqSrcQ.enq(src);
			FlashCmd fcmd = FlashCmd{
				tag: truncate(tag),
				op: READ_PAGE,

				bus: truncate(bus),
				chip: truncate(chip),
				block: truncate(block),
				page: truncate(page)
				};

			flashCmdQ.enq(fcmd);
		end else begin
			indication.readPage(addr, zeroExtend(src), zeroExtend(datasource));
			hostReqTimestampQ.enq(latencyCounter);
			if ( datasource < 3 ) hostDmaTimestampQ.enq(latencyCounter);
		end
	endrule
	
	rule recvTestData3;
		let rst <- aend3.user.receive;
		let sketch = tpl_1(rst);
		readReqTimestampQ.deq;
		Bit#(32) elapsed = latencyCounter - readReqTimestampQ.first;
		//indication.hexDump(elapsed);
		indication.timeDiffDump(elapsed, 3);
		//let data <- auroraExt.user[2].receive;

		//dataQ.enq(truncate(data));
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

// DRAM access end /////////////////////////////////////////



// Host memory access start ////////////////////////////////
	Reg#(Bit#(32)) dmaReadRef <- mkReg(0);
	Vector#(4, Reg#(Bit#(32))) dmaReadCnt <- replicateM(mkReg(0));

	for ( Integer ridx = 0; ridx < 4; ridx = ridx + 1 ) begin
		FIFO#(Bit#(64)) dataRQ <- mkSizedFIFO(32);
		Reg#(Bit#(16)) dataInC <- mkReg(0);
		Reg#(Bit#(16)) dataOutC <- mkReg(0);

		FIFO#(Bool) readReqLastPage <- mkSizedFIFO(32);

		rule initDmaRead (dmaReadCnt[ridx] > 0 && 
			dataInC-dataOutC < 128);
			let dmaCmd = MemengineCmd {
				sglId: dmaReadRef,
				base: zeroExtend(dmaReadCnt[ridx])+(fromInteger(ridx)*(8192/4)),
				len: 128,
				burstLen:128
			};
			re.readServers[ridx].request.put(dmaCmd);
			dmaReadCnt[ridx] <= dmaReadCnt[ridx] - 128;
			dataInC <= dataInC + 128;
			if ( dmaReadCnt[ridx] -128 == 0 ) begin
				readReqLastPage.enq(True);
			end else begin
				readReqLastPage.enq(False);
			end
		endrule
		Reg#(Maybe#(Bit#(64))) rDataBuff <- mkReg(tagged Invalid);
		rule readDmaWord;
			let d <- toGet(re.dataPipes[ridx]).get;
			dataRQ.enq(d);
		endrule
		rule relaySerDma;
			dataRQ.deq;
			let d = dataRQ.first;

			dataOutC <= dataOutC + 8;
			if ( isValid(rDataBuff) ) begin
				
				ser[ridx%2].enq({fromMaybe(?, rDataBuff), d});
				rDataBuff <= tagged Invalid;
			end else begin
				rDataBuff <= tagged Valid d;
			end
		endrule
		rule flushReadResp;
			let dummy <- re.readServers[ridx].response.get;
			readReqLastPage.deq;
			if ( readReqLastPage.first == True ) begin
				hostDmaTimestampQ.deq;
				indication.timeDiffDump(latencyCounter - hostDmaTimestampQ.first, 2);
			end
		endrule
	end


   interface GeneralRequest request;
	method Action readRemotePage(Bit#(64) addr, Bit#(32) node, Bit#(32) source, Bit#(32) tag);
		aend2.user.send(tuple3(addr, truncate(source), truncate(tag)),truncate(node));
		readReqTimestampQ.enq(latencyCounter);
	endmethod
	method Action readPageDone(Bit#(32) sketch);
		//readReqTimestampQ.deq;
		//Bit#(32) elapsed = latencyCounter - readReqTimestampQ.first;
		//readReqSrcQ.deq;
		aend3.user.send(sketch, curDataDst);
		hostReqTimestampQ.deq;
		
		// ttype == 1 : round trip to host
		indication.timeDiffDump(latencyCounter - hostReqTimestampQ.first, 1);
	endmethod
	method Action sendDMAPage(Bit#(32) rdref, Bit#(32) dst);
		curDataDst <= truncate(dst);
		for ( Integer i = 0; i < 4; i = i + 1) begin
			dmaReadCnt[i] <= 8192/4;
		end
		// ttype == 1 : round trip to host
		indication.timeDiffDump(latencyCounter - hostReqTimestampQ.first, 1);
	endmethod
	method Action setDebugVals (Bit#(32) flag, Bit#(32) debugDelay); 
		delayRegSet <= debugDelay;
	endmethod
	method Action setAuroraExtRoutingTable(Bit#(32) node, Bit#(32) portidx, Bit#(32) portsel);
		auroraExtArbiter.setRoutingTable(truncate(node), truncate(portidx), truncate(portsel));
	endmethod
	method Action start(Bit#(32) dummy);
		started <= True;
	endmethod
	method Action setNetId(Bit#(32) netid);
		myNetIdx <= truncate(netid);
	endmethod
	endinterface
   interface ObjectReadClient dmaReadClient = re.dmaClient;
   interface ObjectWriteClient dmaWriteClient = we.dmaClient;
   //interface ObjectReadClient dmaReadClient = dmaReadClients;
   //interface ObjectWriteClient dmaWriteClient = dmaWriteClients;

   //interface Aurora_Pins aurora_fmc1 = auroraIntra1.aurora;
   interface Aurora_Pins aurora_fmc1 = flashCtrl.aurora;
   interface Aurora_Clock_Pins aurora_clk_fmc1 = gtx_clk_fmc1.aurora_clk;

	interface Aurora_Pins aurora_ext = append(auroraExt119.aurora, auroraExt117.aurora);
	interface Aurora_Clock_Pins aurora_quad119 = gtx_clk_119.aurora_clk;
	interface Aurora_Clock_Pins aurora_quad117 = gtx_clk_117.aurora_clk;
endmodule

