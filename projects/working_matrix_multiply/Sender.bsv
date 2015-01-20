import Vector::*;
import HaskellLib::*;
import Connectable::*;
import Base::*;
import Primitive::*;
export Sender::*;

import Library::*;
export Library::*;

import Fifo::*;
export Fifo::*;

import Parameters::*;
export Parameters::*;

typedef Pair#(Bit#(TAdd#(TLog#(MaxBigI), TLog#(NumBuses))), Index#(MaxBigI)) LogicalAddr;
typedef Maybe#(Pair#(Bit#(TAdd#(TLog#(MaxBigI), TLog#(NumBuses))), Index#(MaxBigI))) RealAddr;

interface FinalFifo_;
  interface Vector#(NumBuses, UgFifoDeq_#(Bit#(DataSz))) dataDeq;
  interface Vector#(NumBuses, UgFifoDeq_#(LogicalAddr)) addrDeq;
  interface Vector#(NumBuses, UgFifoEnq_#(Bit#(HostSz))) dataEnq;
  interface Vector#(NumBuses, UgFifoEnq_#(Pair#(RealAddr, Pair#(NumElems#(NumBuses), NumElems#(DataSz))))) ctrlEnq;
  interface ConditionalOutput#(Size) setSize;
  interface Vector#(NumBuses, UgFifoDeq_#(Bit#(BurstRespSz))) burstResp;
endinterface

interface FinalFifo;
  interface Vector#(NumBuses, UgFifoDeq#(Bit#(DataSz))) dataDeq;
  interface Vector#(NumBuses, UgFifoDeq#(LogicalAddr)) addrDeq;
  interface Vector#(NumBuses, UgFifoEnq#(Bit#(HostSz))) dataEnq;
  interface Vector#(NumBuses, UgFifoEnq#(Pair#(RealAddr, Pair#(NumElems#(NumBuses), NumElems#(DataSz))))) ctrlEnq;
  interface ConditionalOutput_#(Size) setSize;
  interface Vector#(NumBuses, UgFifoDeq#(Bit#(BurstRespSz))) burstResp;
endinterface

module _FinalFifo(Tuple2#(FinalFifo_, FinalFifo)) ;
  Tuple2#(Vector#(NumBuses, UgFifoDeq_#(Bit#(DataSz))), Vector#(NumBuses, UgFifoDeq#(Bit#(DataSz)))) dataDeq_ <- replicateTupleM(_UgFifoDeq);
  Tuple2#(Vector#(NumBuses, UgFifoDeq_#(LogicalAddr)), Vector#(NumBuses, UgFifoDeq#(LogicalAddr))) addrDeq_ <- replicateTupleM(_UgFifoDeq);
  Tuple2#(Vector#(NumBuses, UgFifoEnq_#(Bit#(HostSz))), Vector#(NumBuses, UgFifoEnq#(Bit#(HostSz)))) dataEnq_ <- replicateTupleM(_UgFifoEnq);
  Tuple2#(Vector#(NumBuses, UgFifoEnq_#(Pair#(RealAddr, Pair#(NumElems#(NumBuses), NumElems#(DataSz))))), Vector#(NumBuses, UgFifoEnq#(Pair#(RealAddr, Pair#(NumElems#(NumBuses), NumElems#(DataSz)))))) ctrlEnq_ <- replicateTupleM(_UgFifoEnq);
  Tuple2#(ConditionalOutput_#(Size), ConditionalOutput#(Size)) setSize_ <- _ConditionalOutput(True, True);
  Tuple2#(Vector#(NumBuses, UgFifoDeq_#(Bit#(BurstRespSz))), Vector#(NumBuses, UgFifoDeq#(Bit#(BurstRespSz)))) burstResp_ <- replicateTupleM(_UgFifoDeq);
  return tuple2(
    interface FinalFifo_;
      interface dataDeq = tpl_1(asIfc(dataDeq_));
      interface addrDeq = tpl_1(asIfc(addrDeq_));
      interface dataEnq = tpl_1(asIfc(dataEnq_));
      interface ctrlEnq = tpl_1(asIfc(ctrlEnq_));
      interface setSize = tpl_2(asIfc(setSize_));
      interface burstResp = tpl_1(asIfc(burstResp_));
    endinterface,
    interface FinalFifo;
      interface dataDeq = tpl_2(asIfc(dataDeq_));
      interface addrDeq = tpl_2(asIfc(addrDeq_));
      interface dataEnq = tpl_2(asIfc(dataEnq_));
      interface ctrlEnq = tpl_2(asIfc(ctrlEnq_));
      interface setSize = tpl_1(asIfc(setSize_));
      interface burstResp = tpl_2(asIfc(burstResp_));
    endinterface);
endmodule

instance Connectable#(FinalFifo, FinalFifo_) ;
  module mkConnection#(FinalFifo a, FinalFifo_ b)();
    mkConnection(asIfc(a.dataDeq), asIfc(b.dataDeq));
    mkConnection(asIfc(a.addrDeq), asIfc(b.addrDeq));
    mkConnection(asIfc(a.dataEnq), asIfc(b.dataEnq));
    mkConnection(asIfc(a.ctrlEnq), asIfc(b.ctrlEnq));
    mkConnection(asIfc(a.setSize), asIfc(b.setSize));
    mkConnection(asIfc(a.burstResp), asIfc(b.burstResp));
  endmodule
endinstance

instance Connectable#(FinalFifo_, FinalFifo) ;
  module mkConnection#(FinalFifo_ a, FinalFifo b)();
    mkConnection(asIfc(b), asIfc(a));
  endmodule
endinstance

typedef TDiv#(TMul#(MaxBigI, TMul#(MaxBigI, TMul#(NumBuses, NumBuses))), NumBuses) TotalSize;

(* synthesize *)
module mkFinalFifo(FinalFifo) ;
  Tuple2#(FinalFifo_, FinalFifo) mod_ <- _FinalFifo;

  Reg#(NumElems#(TotalSize)) totalCount <- mkReg(0);
  Reg#(NumElems#(TotalSize)) actTotalCount <- mkRegU;
  Reg#(Index#(NumBuses)) roundRobin <- mkReg(0);

  Vector#(NumBuses, Reg#(Bool)) startData <- replicateM(mkReg(False));

  Vector#(NumBuses, Reg#(NumElems#(NumBuses))) n <- replicateM(mkRegU);

  Reg#(Bool) busy <- mkReg(False);

  Reg#(NumElems#(MaxBigI)) maxI <- mkRegU;
  Reg#(NumElems#(MaxBigI)) maxJ <- mkRegU;

  (* fire_when_enabled *) rule init(!busy && (tpl_1(asIfc(mod_))).setSize.en);
    busy <= True;
    maxI <= (tpl_1(asIfc(mod_))).setSize.maxI;
    maxJ <= (tpl_1(asIfc(mod_))).setSize.maxJ;
    totalCount <= 0;
    roundRobin <= 0;
    Integer scale = ((fromInteger(valueOf(NumBuses)) * fromInteger(valueOf(NumBuses))) / fromInteger(valueOf(NumBuses)));
    actTotalCount <= zeroExtend((tpl_1(asIfc(mod_))).setSize.maxI) * zeroExtend((tpl_1(asIfc(mod_))).setSize.maxJ) * fromInteger(scale);
    
    for(Integer x = 0; x < valueOf(NumBuses); x=x+1)
    begin
      n[x] <= 0;
      startData[x] <= False;
    end
  endrule

  (* fire_when_enabled *) rule getBurstResp(busy && (tpl_1(asIfc(mod_))).burstResp[roundRobin].notEmpty);
    (tpl_1(asIfc(mod_))).burstResp[roundRobin].deq;
    roundRobin <= roundRobin + 1;
    totalCount <= totalCount + 1;
  endrule

  function RealAddr convert(LogicalAddr a) = tagged Valid a;
  RealAddr flagAddr = tagged Invalid;

  for(Integer x = 0; x < valueOf(NumBuses); x=x+1)
  begin
    (* fire_when_enabled *) rule sendAddr(!startData[x] && busy && (tpl_1(asIfc(mod_))).ctrlEnq[x].notFull && (tpl_1(asIfc(mod_))).addrDeq[x].notEmpty &&
                    n[x] == 0 &&
                    totalCount < actTotalCount);
      (tpl_1(asIfc(mod_))).addrDeq[x].deq;
      startData[x] <= True;
      (tpl_1(asIfc(mod_))).ctrlEnq[x].enq.write( Pair{fst: convert((tpl_1(asIfc(mod_))).addrDeq[x].first),
                             snd: Pair{fst: fromInteger(valueOf(NumBuses)),
                                       snd: fromInteger(valueOf(DataSz))}});
    endrule

    (* fire_when_enabled *) rule sendData(busy && (tpl_1(asIfc(mod_))).dataEnq[x].notFull && n[x] < fromInteger(valueOf(NumBuses)) &&
                    startData[x] && totalCount < actTotalCount);
      (tpl_1(asIfc(mod_))).dataDeq[x].deq;
      (tpl_1(asIfc(mod_))).dataEnq[x].enq.write( zeroExtend((tpl_1(asIfc(mod_))).dataDeq[x].first));
      n[x] <= n[x] + 1;
    endrule

    (* fire_when_enabled *) rule finishSend(busy && n[x] == fromInteger(valueOf(NumBuses)) && startData[x]);
      n[x] <= 0;
      startData[x] <= False;
    endrule

  end

  (* fire_when_enabled *) rule finalDone(busy && totalCount == actTotalCount && (tpl_1(asIfc(mod_))).ctrlEnq[0].notFull && (tpl_1(asIfc(mod_))).dataEnq[0].notFull);
    (tpl_1(asIfc(mod_))).ctrlEnq[0].enq.write( Pair{fst: flagAddr, snd: Pair{fst: 0, snd: fromInteger(valueOf(HostSz))}});
    (tpl_1(asIfc(mod_))).dataEnq[0].enq.write( 1);
    busy <= False;
  endrule

  return tpl_2(asIfc(mod_));
endmodule

interface SendFifo_;
  interface UgFifoEnq#(Pair#(Bool, Bit#(DataSz))) enq;
  interface UgFifoDeq#(Bit#(DataSz)) deq;
endinterface

interface SendFifo;
  interface UgFifoEnq_#(Pair#(Bool, Bit#(DataSz))) enq;
  interface UgFifoDeq_#(Bit#(DataSz)) deq;
endinterface

module _SendFifo(Tuple2#(SendFifo_, SendFifo)) ;
  Tuple2#(UgFifoEnq_#(Pair#(Bool, Bit#(DataSz))), UgFifoEnq#(Pair#(Bool, Bit#(DataSz)))) enq_ <- _UgFifoEnq;
  Tuple2#(UgFifoDeq_#(Bit#(DataSz)), UgFifoDeq#(Bit#(DataSz))) deq_ <- _UgFifoDeq;
  return tuple2(
    interface SendFifo_;
      interface enq = tpl_2(asIfc(enq_));
      interface deq = tpl_2(asIfc(deq_));
    endinterface,
    interface SendFifo;
      interface enq = tpl_1(asIfc(enq_));
      interface deq = tpl_1(asIfc(deq_));
    endinterface);
endmodule

instance Connectable#(SendFifo, SendFifo_) ;
  module mkConnection#(SendFifo a, SendFifo_ b)();
    mkConnection(asIfc(a.enq), asIfc(b.enq));
    mkConnection(asIfc(a.deq), asIfc(b.deq));
  endmodule
endinstance

instance Connectable#(SendFifo_, SendFifo) ;
  module mkConnection#(SendFifo_ a, SendFifo b)();
    mkConnection(asIfc(b), asIfc(a));
  endmodule
endinstance

(* synthesize *)
module mkSendFifo(SendFifo) ;
  Tuple2#(SendFifo_, SendFifo) mod_ <- _SendFifo;

  RegFile#(1, 1, NumBuses, Bit#(DataSz)) rf <- mkRegFileU;
  Reg#(Index#(NumBuses)) enqIdx <- mkReg(0);
  Reg#(Index#(NumBuses)) deqIdx <- mkReg(0);
  Reg#(NumElems#(NumBuses)) numElems <- mkReg(0);

  (* fire_when_enabled *) rule a;
    NumElems#(NumBuses) numEnqs = zeroExtend(pack((tpl_1(asIfc(mod_))).enq.enq.en));

    rf.read[0].req.write( (tpl_1(asIfc(mod_))).enq.enq.en? enqIdx : deqIdx);

    if((tpl_1(asIfc(mod_))).enq.enq.en)
    begin
      rf.write[0].write(
        Pair{fst: enqIdx, snd: ((tpl_1(asIfc(mod_))).enq.enq.fst? 0 : rf.read[0].resp) + (tpl_1(asIfc(mod_))).enq.enq.snd});

      enqIdx <= enqIdx + 1;

      $display("%d %m ReadValue: %d %d %d", $time, enqIdx, ((tpl_1(asIfc(mod_))).enq.enq.fst? 0: rf.read[0].resp), (tpl_1(asIfc(mod_))).enq.enq.snd);
    end

    NumElems#(NumBuses) numDeqs = zeroExtend(pack((tpl_1(asIfc(mod_))).deq.deq));
    numElems <= numElems + (numEnqs - numDeqs);
    (tpl_1(asIfc(mod_))).enq.notFull.write( True);

    (tpl_1(asIfc(mod_))).deq.notEmpty.write( True);
    (tpl_1(asIfc(mod_))).deq.first.write( rf.read[0].resp);
  endrule

  return tpl_2(asIfc(mod_));
endmodule

interface Sender_;
  interface Output_#(Bool) busy;
  interface ConditionalOutput#(Size) setSize;
  interface UgFifoDeq_#(Vector#(NumBuses, Bit#(DataSz))) fromMult;
  interface Vector#(NumBuses, UgFifoDeq#(Bit#(DataSz))) dataDeq;
  interface Vector#(NumBuses, UgFifoDeq#(LogicalAddr)) addrDeq;
  interface ConditionalOutput_#(Pair#(Size, Index#(MaxBigK))) sendSize;
endinterface

interface Sender;
  interface Output#(Bool) busy;
  interface ConditionalOutput_#(Size) setSize;
  interface UgFifoDeq#(Vector#(NumBuses, Bit#(DataSz))) fromMult;
  interface Vector#(NumBuses, UgFifoDeq_#(Bit#(DataSz))) dataDeq;
  interface Vector#(NumBuses, UgFifoDeq_#(LogicalAddr)) addrDeq;
  interface ConditionalOutput#(Pair#(Size, Index#(MaxBigK))) sendSize;
endinterface

module _Sender(Tuple2#(Sender_, Sender)) ;
  Tuple2#(Output_#(Bool), Output#(Bool)) busy_ <- _Output(True, True);
  Tuple2#(ConditionalOutput_#(Size), ConditionalOutput#(Size)) setSize_ <- _ConditionalOutput(True, True);
  Tuple2#(UgFifoDeq_#(Vector#(NumBuses, Bit#(DataSz))), UgFifoDeq#(Vector#(NumBuses, Bit#(DataSz)))) fromMult_ <- _UgFifoDeq;
  Tuple2#(Vector#(NumBuses, UgFifoDeq_#(Bit#(DataSz))), Vector#(NumBuses, UgFifoDeq#(Bit#(DataSz)))) dataDeq_ <- replicateTupleM(_UgFifoDeq);
  Tuple2#(Vector#(NumBuses, UgFifoDeq_#(LogicalAddr)), Vector#(NumBuses, UgFifoDeq#(LogicalAddr))) addrDeq_ <- replicateTupleM(_UgFifoDeq);
  Tuple2#(ConditionalOutput_#(Pair#(Size, Index#(MaxBigK))), ConditionalOutput#(Pair#(Size, Index#(MaxBigK)))) sendSize_ <- _ConditionalOutput(True, True);
  return tuple2(
    interface Sender_;
      interface busy = tpl_1(asIfc(busy_));
      interface setSize = tpl_2(asIfc(setSize_));
      interface fromMult = tpl_1(asIfc(fromMult_));
      interface dataDeq = tpl_2(asIfc(dataDeq_));
      interface addrDeq = tpl_2(asIfc(addrDeq_));
      interface sendSize = tpl_1(asIfc(sendSize_));
    endinterface,
    interface Sender;
      interface busy = tpl_2(asIfc(busy_));
      interface setSize = tpl_1(asIfc(setSize_));
      interface fromMult = tpl_2(asIfc(fromMult_));
      interface dataDeq = tpl_1(asIfc(dataDeq_));
      interface addrDeq = tpl_1(asIfc(addrDeq_));
      interface sendSize = tpl_2(asIfc(sendSize_));
    endinterface);
endmodule

instance Connectable#(Sender, Sender_) ;
  module mkConnection#(Sender a, Sender_ b)();
    mkConnection(asIfc(a.busy), asIfc(b.busy));
    mkConnection(asIfc(a.setSize), asIfc(b.setSize));
    mkConnection(asIfc(a.fromMult), asIfc(b.fromMult));
    mkConnection(asIfc(a.dataDeq), asIfc(b.dataDeq));
    mkConnection(asIfc(a.addrDeq), asIfc(b.addrDeq));
    mkConnection(asIfc(a.sendSize), asIfc(b.sendSize));
  endmodule
endinstance

instance Connectable#(Sender_, Sender) ;
  module mkConnection#(Sender_ a, Sender b)();
    mkConnection(asIfc(b), asIfc(a));
  endmodule
endinstance

(* synthesize *)
module mkSender(Sender) ;
  Tuple2#(Sender_, Sender) mod_ <- _Sender;

  Vector#(NumBuses, SendFifo) dataFifos <- replicateM(mkSendFifo);
  Vector#(NumBuses, UgFifo#(1, LogicalAddr))
                              addrFifos <- replicateM(mkUgFifo);

  Reg#(Bool) busyReg <- mkReg(False);

  Reg#(Index#(MaxBigI)) bigI <- mkReg(0);
  Reg#(Index#(MaxBigK)) bigK <- mkReg(0);
  Reg#(Index#(MaxBigI)) bigJ <- mkReg(0);

  Reg#(NumElems#(NumBuses)) i <- mkReg(0);

  Reg#(NumElems#(MaxBigI)) maxI <- mkRegU;
  Reg#(NumElems#(MaxBigK)) maxK <- mkRegU;
  Reg#(NumElems#(MaxBigI)) maxJ <- mkRegU;

  (* fire_when_enabled *) rule r0;
    (tpl_1(asIfc(mod_))).busy.write( busyReg);
  endrule

  function Bool addrNotFull(Integer x) = addrFifos[x].enq.notFull;
  function Bool myAnd(Bool x, Bool y) = x && y;
  Vector#(NumBuses, Bool) addrNotFullVec = genWith(addrNotFull);
  Bool addrFifosNotFull = fold(myAnd, addrNotFullVec);

  (* fire_when_enabled *) rule init(!busyReg && (tpl_1(asIfc(mod_))).setSize.en && addrFifosNotFull);
    maxI <= (tpl_1(asIfc(mod_))).setSize.maxI;
    maxJ <= (tpl_1(asIfc(mod_))).setSize.maxJ;
    maxK <= zeroExtend((tpl_1(asIfc(mod_))).setSize.maxK) * fromInteger(valueOf(NumPackets));
    bigI <= 0;
    bigK <= 0;
    bigJ <= 0;
    i <= 0;

    busyReg <= True;
  endrule

  (* fire_when_enabled *) rule getMult(busyReg && (tpl_1(asIfc(mod_))).fromMult.notEmpty && i < fromInteger(valueOf(NumBuses)) &&
                addrFifosNotFull);
    (tpl_1(asIfc(mod_))).fromMult.deq;
    for(Integer x = 0; x < valueOf(NumBuses); x=x+1)
    begin
      Index#(NumBuses) xDash = fromInteger(x);
      Index#(NumBuses) iDash = truncate(i);
      $display("%d Sender Enqueued: %d %d %d %d %d", $time, {bigI, xDash}, {bigJ, iDash}, bigK, bigK == 0, (tpl_1(asIfc(mod_))).fromMult.first[x]);
      dataFifos[x].enq.enq.write( Pair{fst: bigK == 0, snd: (tpl_1(asIfc(mod_))).fromMult.first[x]});
    end
    i <= i + 1;
  endrule

  (* fire_when_enabled *) rule getMultNextRow(busyReg && i == fromInteger(valueOf(NumBuses)) &&
                        addrFifosNotFull);
    i <= 0;

    Index#(MaxBigI) tBigK = truncate(bigK);
    if(maxBound == tBigK)
      (tpl_1(asIfc(mod_))).sendSize.write( Pair{fst: Size{maxI: zeroExtend(bigI), maxJ: zeroExtend(bigJ), maxK: 0}, snd: bigK});
    if(zeroExtend(bigK) == maxK - 1)
    begin
      bigK <= 0;

      for(Integer x = 0; x < valueOf(NumBuses); x=x+1)
      begin
        let addr = Pair{fst: {bigI, Index#(NumBuses)'(fromInteger(x))}, snd: bigJ};
        addrFifos[x].enq.enq.write( addr);
      end
      if(zeroExtend(bigJ) == maxJ - 1)
      begin
        bigI <= bigI + 1;
        bigJ <= 0;
        if(zeroExtend(bigI) == maxI - 1)
        begin
          $display("%d Sender everything done", $time);
          busyReg <= False;
        end
      end
      else
        bigJ <= bigJ + 1;
    end
    else
      bigK <= bigK + 1;
  endrule

  for(Integer x = 0; x < valueOf(NumBuses); x=x+1)
  begin
    mkConnection(asIfc((tpl_1(asIfc(mod_))).dataDeq[x]), asIfc( dataFifos[x].deq));
    mkConnection(asIfc((tpl_1(asIfc(mod_))).addrDeq[x]), asIfc( addrFifos[x].deq));
  end

  return tpl_2(asIfc(mod_));
endmodule

