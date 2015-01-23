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

import StreamingSerDes::*;


typedef 8 WordBytes;
typedef TMul#(8,WordBytes) WordSz;

interface GeneralRequest;
	method Action setAuroraExtRoutingTable(Bit#(32) node, Bit#(32) portidx, Bit#(32) portsel);
	method Action setNetId(Bit#(32) netid);
	method Action start(Bit#(32) dummy);

	method Action sendData(Bit#(32) count, Bit#(6) target, Bit#(32) stride);
	method Action auroraStatus(Bit#(32) dummy);
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

	interface Vector#(AuroraExtCount, Aurora_Pins#(1)) aurora_ext;
	interface Aurora_Clock_Pins aurora_quad119;
	interface Aurora_Clock_Pins aurora_quad117;
endinterface

typedef enum {Flash, Host, DRAM, PageCache} DataSource deriving (Bits,Eq);

typedef enum {Read,Write,Erase} CmdType deriving (Bits,Eq);
//typedef struct { Bit#(5) channel; Bit#(5) chip; Bit#(8) block; Bit#(8) page; CmdType cmd; Bit#(8) tag; Bit#(8) bufidx;} FlashCmd deriving (Bits,Eq);

module mkMain#(GeneralIndication indication
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

	//AuroraIfc auroraIntra1 <- mkAuroraIntra(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);

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
	AuroraEndpointIfc#(Bit#(106)) aendData1 <- mkAuroraEndpoint(3, myNetIdx);
	AuroraEndpointIfc#(Bit#(106)) aendData2 <- mkAuroraEndpoint(4, myNetIdx);

	//let alist1 = nil;
	let alist1 = cons(aend1.cmd, nil);
	let alist2 = cons(aend2.cmd, alist1);
	let alist3 = cons(aend3.cmd, alist2);
	let alist4 = cons(aendData2.cmd, cons(aendData1.cmd, alist3));

	let auroraList = alist4;
	AuroraExtArbiterIfc auroraExtArbiter <- mkAuroraExtArbiter(
		append(auroraExt119.user, auroraExt117.user)
		, auroraList, myNetIdx);
	

	Reg#(Bit#(32)) latencyCounter <- mkReg(0);
	rule incLatencyCounter;
		latencyCounter <= latencyCounter + 1;
	endrule

	Reg#(Bit#(32)) sendDataCount <- mkReg(0);
	Reg#(Bit#(6)) sendDataTarget <- mkReg(0);
	Reg#(Bit#(32)) sendDataStride <- mkReg(0);
	Reg#(Bit#(32)) sendDataStrideCount <- mkReg(0);
	rule sendAuroraData(sendDataCount > 0 );
		if ( sendDataStrideCount > 0 ) begin
			sendDataStrideCount <= sendDataStrideCount - 1;
		end else begin
			sendDataStrideCount <= sendDataStride;

			sendDataCount <= sendDataCount - 1;
			
			aendData1.user.send(zeroExtend(sendDataCount), sendDataTarget);
			aendData2.user.send(zeroExtend(sendDataCount), sendDataTarget);
		end
	endrule

	Reg#(Bit#(32)) recvDataCount <- mkReg(0);
	rule recvAuroraData;
		recvDataCount <= recvDataCount + 1;

		let rst <- aendData1.user.receive;
		let rst2 <- aendData2.user.receive;
		let data = tpl_1(rst);
		let src = tpl_2(rst);

		Bit#(9) dataCU = truncate(recvDataCount);
		if ( dataCU == 0 ) begin
			indication.hexDump(truncate(data));
		end
	endrule


   interface GeneralRequest request;

	method Action sendData(Bit#(32) count, Bit#(6) target, Bit#(32) stride);
		sendDataCount <= sendDataCount + count;
		sendDataTarget <= target;
		sendDataStride <= stride;
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
	method Action auroraStatus(Bit#(32) dummy);
		indication.hexDump({
			0,
			auroraExt117.user[3].channel_up,
			auroraExt117.user[2].channel_up,
			auroraExt117.user[1].channel_up,
			auroraExt117.user[0].channel_up,

			auroraExt119.user[3].channel_up,
			auroraExt119.user[2].channel_up,
			auroraExt119.user[1].channel_up,
			auroraExt119.user[0].channel_up
		});
	endmethod
	endinterface
   interface ObjectReadClient dmaReadClient = re.dmaClient;
   interface ObjectWriteClient dmaWriteClient = we.dmaClient;
   //interface ObjectReadClient dmaReadClient = dmaReadClients;
   //interface ObjectWriteClient dmaWriteClient = dmaWriteClients;

	interface Aurora_Pins aurora_ext = append(auroraExt119.aurora, auroraExt117.aurora);
	interface Aurora_Clock_Pins aurora_quad119 = gtx_clk_119.aurora_clk;
	interface Aurora_Clock_Pins aurora_quad117 = gtx_clk_117.aurora_clk;
endmodule

