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

import ConnectalMemory::*;
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

import AuroraExtArbiterBar::*;
import AuroraExtEndpoint::*;
import AuroraExtImport::*;
//import AuroraExtImport117::*;
import AuroraCommon::*;

import StreamingSerDes::*;


typedef 16 WordBytes;
typedef TMul#(8,WordBytes) WordSz;

interface GeneralRequest;
	method Action setAuroraExtRoutingTable(Bit#(32) node, Bit#(32) portidx, Bit#(32) portsel);
	method Action setNetId(Bit#(32) netid);
	method Action start(Bit#(32) dummy);

	method Action sendData(Bit#(32) count, Bit#(5) target, Bit#(32) stride);
	method Action auroraStatus(Bit#(32) dummy);
endinterface

interface GeneralIndication;
	method Action readPage(Bit#(64) addr, Bit#(32) dstnod, Bit#(32) datasource);
	method Action recvSketch(Bit#(32) sketch, Bit#(32) latency);
	method Action hexDump(Bit#(32) hex);
	method Action mismatch(Bit#(32) hex, Bit#(32) hex2);
	method Action timeDiffDump(Bit#(32) diff, Bit#(32) ttype);
endinterface

// NumDmaChannels each for flash i/o and emualted i/o
//typedef TAdd#(NumDmaChannels, NumDmaChannels) NumObjectClients;
//typedef NumDmaChannels NumObjectClients;

interface MainIfc;
	interface GeneralRequest request;
	interface MemReadClient#(WordSz) dmaReadClient;
	interface MemWriteClient#(WordSz) dmaWriteClient;

	interface Vector#(AuroraExtPerQuad, Aurora_Pins#(1)) aurora_ext;
	interface Aurora_Clock_Pins aurora_quad119;
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


	MemwriteEngine#(WordSz,1,4) we <- mkMemwriteEngineBuff(512);
	MemreadEngine#(WordSz,1,4)  re <- mkMemreadEngineBuff(512);















	AuroraEndpointIfc#(Bit#(128)) aend1 <- mkAuroraEndpointDynamic(100, 100, 100);
	//AuroraEndpointIfc#(Bit#(128)) aend1 <- mkAuroraEndpointStatic(128, 64);
	AuroraEndpointIfc#(Bit#(128)) aend2 <- mkAuroraEndpointStatic(128, 64);
	//AuroraEndpointIfc#(Bit#(128)) aend1 <- mkAuroraEndpointDynamic(128, 128, 300);
	let auroraList = cons(aend2.cmd, cons(aend1.cmd, nil));
	
	GtxClockImportIfc gtx_clk_119 <- mkGtxClockImport;
	AuroraExtIfc auroraExt119 <- mkAuroraExt(gtx_clk_119.gtx_clk_p_ifc, gtx_clk_119.gtx_clk_n_ifc, clk50);

	AuroraExtArbiterBarIfc auroraExtArbiter <- mkAuroraExtArbiterBar(auroraExt119.user, auroraList);

	Reg#(Bit#(32)) latencyCounter <- mkReg(0);
	rule incLatencyCounter;
		latencyCounter <= latencyCounter + 1;
	endrule

	Reg#(Bit#(32)) sendDataCount <- mkReg(0);
	Reg#(Bit#(32)) sendDataCount2 <- mkReg(0);
	Reg#(HeaderField) sendDataTarget <- mkReg(0);
	Reg#(Bit#(32)) sendDataStride <- mkReg(0);
	Reg#(Bit#(32)) sendDataStrideCount <- mkReg(0);
	rule sendAuroraData2(sendDataCount2 > 0 );
		sendDataCount2 <= sendDataCount2 - 1;
		aend2.user.send(zeroExtend({sendDataCount2,8'hcc}), sendDataTarget);
	endrule

	rule sendAuroraData(sendDataCount > 0 );
		if ( sendDataStrideCount > 0 ) begin
			sendDataStrideCount <= sendDataStrideCount - 1;
		end else begin
			sendDataStrideCount <= sendDataStride;

			sendDataCount <= sendDataCount - 1;
			
			aend1.user.send(zeroExtend(sendDataCount), sendDataTarget);
			$display( "Sent data %x to %d", sendDataCount, sendDataTarget);
			//auroraExt119.user[0].send(AuroraPacket{src:0, dst:0, ptype:1, payload: zeroExtend(sendDataCount)});
			//auroraExt119.user[1].send(AuroraPacket{src:2, dst:2, ptype:4, payload: zeroExtend(sendDataCount)});
		end
	endrule

	Reg#(Bit#(32)) lastDataIn1 <- mkReg(0);
	Reg#(Bit#(32)) recvDataCount <- mkReg(0);
	rule recvAuroraData;
		recvDataCount <= recvDataCount + 1;
		
		let rst <- aend1.user.receive;
		//let rst2 <- aend2.user.receive;
		let data = tpl_1(rst);
		let src = tpl_2(rst);
		$display( "endpoint received %x from %d", data, tpl_2(rst) );

		/*
		//let rcv1 <- auroraExt119.user[2].receive;
		let rcv2 <- auroraExt119.user[3].receive;
		let data = rcv2.payload;
		$display( "received %x from %d", data, rcv2.src );
		*/
		lastDataIn1 <= truncate(data);
		if ( lastDataIn1 -1 != truncate(data) ) begin
			$display( "Data mismatch at aend 1 %x %x", lastDataIn1, data );
			indication.mismatch(lastDataIn1, truncate(data));
		end


		Bit#(14) dataCU = truncate(recvDataCount);
		if ( dataCU == 0 ) begin
			indication.hexDump(truncate(data));
			//indication.hexDump({truncate(data), src[3:0]});
		end
	endrule
	
	Reg#(Bit#(32)) lastDataIn2 <- mkReg(0);
	Reg#(Bit#(32)) aend2Throttle <- mkReg(0);
	/*
	rule recvAuroraData2;
		aend2Throttle <= aend2Throttle + 1;
		Bit#(18) aet = truncate(aend2Throttle);

		if ( aet == 0 ) begin
			let rst <- aend2.user.receive;
			let data = tpl_1(rst);
			lastDataIn2 <= truncate(data);
			if ( lastDataIn2 - 32'h100 != truncate(data) ) begin
				$display( "Data mismatch at aend 2 %x %x", lastDataIn2, data );
			end
		end
	endrule
	*/


   interface GeneralRequest request;

	method Action sendData(Bit#(32) count, Bit#(5) target, Bit#(32) stride);
		sendDataCount <= sendDataCount + count;
		sendDataCount2 <= sendDataCount2 + count;
		sendDataTarget <= target;
		sendDataStride <= stride;
	endmethod
	method Action setAuroraExtRoutingTable(Bit#(32) node, Bit#(32) portidx, Bit#(32) portsel);
		//auroraExtArbiter.setRoutingTable(truncate(node), truncate(portidx), truncate(portsel));
	endmethod
	method Action start(Bit#(32) dummy);
		started <= True;
	endmethod
	method Action setNetId(Bit#(32) netid);
		myNetIdx <= truncate(netid);
		auroraExtArbiter.setMyId(truncate(netid));
		auroraExt119.setNodeIdx(truncate(netid));
	endmethod
	method Action auroraStatus(Bit#(32) dummy);
		indication.hexDump({
			0,
			auroraExt119.user[3].channel_up,
			auroraExt119.user[2].channel_up,
			auroraExt119.user[1].channel_up,
			auroraExt119.user[0].channel_up
		});
	endmethod
	endinterface
	interface MemReadClient dmaReadClient = re.dmaClient;
	interface MemWriteClient dmaWriteClient = we.dmaClient;

	//interface Aurora_Pins aurora_ext = append(auroraExt119.aurora, auroraExt117.aurora);
	interface Aurora_Pins aurora_ext = auroraExt119.aurora;
	interface Aurora_Clock_Pins aurora_quad119 = gtx_clk_119.aurora_clk;
endmodule

