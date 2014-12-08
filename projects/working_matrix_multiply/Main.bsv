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
import FIFOLevel::*;
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
//import AuroraExtArbiter::*;
//import AuroraExtImport::*;
//import AuroraExtImport117::*;
import AuroraCommon::*;

//import PageCache::*;
//import DMABurstHelper::*;
import ControllerTypes::*;
import FlashCtrlVirtex::*;
import FlashCtrlModel::*;

import Parameters::*;
import MatrixMultiply::*;
import Primitive::*;
import Base::*;

interface FlashRequest;
    method Action setMatrixSize(Bit#(32) i, Bit#(32) j, Bit#(32) k, Bit#(32) point, Bit#(32) w);
endinterface

interface FlashIndication;
	method Action finish(Bit#(32) err);
endinterface

// NumDmaChannels each for flash i/o and emualted i/o
//typedef TAdd#(NumDmaChannels, NumDmaChannels) NumObjectClients;
//typedef NumDmaChannels NumObjectClients;
typedef 128 DmaBurstBytes; 
Integer dmaBurstBytes = valueOf(DmaBurstBytes);
Integer dmaBurstWords = dmaBurstBytes/wordBytes; //128/16 = 8
Integer dmaBurstsPerPage = pageSizeUser/dmaBurstBytes;

interface MainIfc;
	interface FlashRequest request;
	interface Vector#(1, ObjectWriteClient#(WordSz)) dmaWriteClient;
	interface Vector#(1, ObjectReadClient#(WordSz)) dmaReadClient;
	interface Aurora_Pins#(4) aurora_fmc1;
	interface Aurora_Clock_Pins aurora_clk_fmc1;
endinterface

module mkMain#(FlashIndication indication, Clock clk250, Reset rst250)(MainIfc);

	GtxClockImportIfc gtx_clk_fmc1 <- mkGtxClockImport;
	`ifdef BSIM
		FlashCtrlVirtexIfc flashCtrl <- mkFlashCtrlModel(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
	`else
		FlashCtrlVirtexIfc flashCtrl <- mkFlashCtrlVirtex(gtx_clk_fmc1.gtx_clk_p_ifc, gtx_clk_fmc1.gtx_clk_n_ifc, clk250);
	`endif

	//Create read/write engines with NUM_BUSES memservers
	MemreadEngineV#(WordSz, 1, NumBuses) re <- mkMemreadEngine;
	MemwriteEngineV#(WordSz, 1, NumBuses) we <- mkMemwriteEngine;


  MatrixMultiply m <- mkMatrixMultiply;
  Reg#(Bit#(32)) count <- mkReg(0);
  Reg#(Bit#(32)) waitTime <- mkRegU;
  Reg#(Bit#(32)) waitt <- mkRegU;

  FIFOF#(FlashCmd) reqFifo <- mkLFIFOF;
  Vector#(2, Vector#(NumBuses, FIFOF#(Bit#(PacketSz)))) respFifo <- replicateM(replicateM(mkFIFOF));

  rule flashSideReqInit1(m.dataReq.en);
    Bit#(1) wh = m.dataReq.fst.fst;
    Index#(NumBuses) iDash = m.dataReq.fst.snd;
    let row = m.dataReq.snd.fst;
    let col = m.dataReq.snd.snd;
    FlashCmd fcmd = FlashCmd{
      tag: zeroExtend({wh, iDash}),
      op: READ_PAGE,
      bus: truncate({Bit#(32)'(0), iDash}),
      chip: {wh, truncate(col)},
      block: zeroExtend(row),
      page: truncateLSB(col)
    };
    $display("%d Send flash request: %d %d %d %d", $time, wh, iDash, row, col);
    reqFifo.enq(fcmd);
  endrule

  rule flashSideReqInit2;
    flashCtrl.user.sendCmd(reqFifo.first);
    reqFifo.deq;
    waitt <= 0;
  endrule

  rule flashSideResp1;
    let tagData <- flashCtrl.user.readWord;
    let tag = tpl_2(tagData);
    let data = tpl_1(tagData);
    Bit#(TAdd#(1, TLog#(NumBuses))) rTag = truncate(tag);
    Bit#(1) wh = truncateLSB(rTag);
    Index#(NumBuses) iDash = truncate(rTag);
    respFifo[wh][iDash].enq(data);
    $display("%d Receive flash response: %d %d %x", $time, wh, iDash, data);
    waitt <= 0;
  endrule

  for(Integer i = 0; i < 2; i = i+1)
    for(Integer j = 0; j < valueOf(NumBuses); j=j+1)
      rule flashSideResp2;
        respFifo[i][j].deq;
        $display("%d Dequeued flash response %d %d", $time, i, j);
        m.dataResp[i][j].write(respFifo[i][j].first);
      endrule

  Reg#(Bit#(32)) pointer <- mkRegU;
  Vector#(NumBuses, FIFOF#(Bool)) ctrlFifo <- replicateM(mkLFIFOF);
  Vector#(NumBuses, FIFOF#(Bit#(DataSz))) dataFifo <- replicateM(mkLFIFOF);
  Vector#(NumBuses, FIFOF#(void)) resp2Fifo <- replicateM(mkLFIFOF);

  for(Integer i = 0; i < valueOf(NumBuses); i=i+1)
  begin
    rule dmaNotFull;
      m.ctrlEnq[i].notFull.write(ctrlFifo[i].notFull);
      m.dataEnq[i].notFull.write(dataFifo[i].notFull);
    endrule

    rule dmaCtrl1(m.ctrlEnq[i].enq.en);
      if(isValid(m.ctrlEnq[i].enq.fst))
        ctrlFifo[i].enq(True);
      else
        ctrlFifo[i].enq(False);
    endrule

    rule dmaCtrl2(ctrlFifo[i].first);
      let dmaCmd = MemengineCmd {
        sglId: pointer,
        base: fromInteger(i),
        len: 128,//fromInteger(valueof(DataSz)/8 * valueOf(NumBuses)),
        burstLen: 128
      };
      we.writeServers[i].request.put(dmaCmd);
      $display("%d DmaCmd", $time);
      ctrlFifo[i].deq;
    endrule

    rule dmaFinish(!ctrlFifo[i].first);
      ctrlFifo[i].deq;
      indication.finish(count);
    endrule

    rule dmaData1(m.dataEnq[i].enq.en);
      dataFifo[i].enq(m.dataEnq[i].enq);
    endrule

    rule dmaData2;
      $display("%d DmaPipe: %d ", $time, dataFifo[i].first);
      we.dataPipes[i].enq(zeroExtend(dataFifo[i].first));
      dataFifo[i].deq;
    endrule

    rule dmaResp1;
      let b <- we.writeServers[i].response.get;
      resp2Fifo[i].enq(?);
    endrule

    rule dmaResp2;
      if(m.burstResp[i].deq)
        resp2Fifo[i].deq;
    endrule

    rule dmaRespVal;
      m.burstResp[i].first.write(0);
      m.burstResp[i].notEmpty.write(resp2Fifo[i].notEmpty);
    endrule
  end

	Vector#(1, ObjectWriteClient#(WordSz)) dmaWriteClientVec;
	Vector#(1, ObjectReadClient#(WordSz)) dmaReadClientVec;
	dmaWriteClientVec[0] = we.dmaClient;
	dmaReadClientVec[0] = re.dmaClient;
		

  interface FlashRequest request;
    method Action setMatrixSize(Bit#(32) i, Bit#(32) j, Bit#(32) k, Bit#(32) point, Bit#(32) w);
      m.setSize.write(Size{maxI: truncate(i), maxJ: truncate(j), maxK: truncate(k)});
      count <= 0;
      pointer <= point;
      waitTime <= w;
    endmethod
  endinterface //FlashRequest

  interface ObjectWriteClient dmaWriteClient = dmaWriteClientVec;
  interface ObjectReadClient dmaReadClient = dmaReadClientVec;

  interface Aurora_Pins aurora_fmc1 = flashCtrl.aurora;
  interface Aurora_Clock_Pins aurora_clk_fmc1 = gtx_clk_fmc1.aurora_clk;

endmodule

