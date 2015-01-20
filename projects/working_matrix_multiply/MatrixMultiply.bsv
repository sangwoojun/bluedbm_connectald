import Vector::*;
import HaskellLib::*;
import Connectable::*;
import Base::*;
import Primitive::*;
export MatrixMultiply::*;

import Sender::*;
export Sender::*;

import Receiver::*;
export Receiver::*;

import Multiply::*;
export Multiply::*;

import Parameters::*;
export Parameters::*;

interface MatrixMultiply_;
  interface Vector#(NumBuses, UgFifoEnq_#(Bit#(HostSz))) dataEnq;
  interface Vector#(NumBuses, UgFifoEnq_#(Pair#(RealAddr, Pair#(NumElems#(NumBuses), NumElems#(DataSz))))) ctrlEnq;
  interface ConditionalOutput#(Size) setSize;
  interface Vector#(NumBuses, UgFifoDeq_#(Bit#(BurstRespSz))) burstResp;
  interface Output_#(Bool) busy;
  interface ConditionalOutput_#(Pair#(Pair#(Bit#(1), Index#(NumBuses)), Pair#(Index#(MaxBigI), Index#(MaxBigI)))) dataReq;
  interface Vector#(2, Vector#(NumBuses, ConditionalOutput#(Bit#(PacketSz)))) dataResp;
  interface ConditionalOutput_#(Size) recvSize;
  interface ConditionalOutput_#(Pair#(Size, Index#(MaxBigK))) sendSize;
endinterface

interface MatrixMultiply;
  interface Vector#(NumBuses, UgFifoEnq#(Bit#(HostSz))) dataEnq;
  interface Vector#(NumBuses, UgFifoEnq#(Pair#(RealAddr, Pair#(NumElems#(NumBuses), NumElems#(DataSz))))) ctrlEnq;
  interface ConditionalOutput_#(Size) setSize;
  interface Vector#(NumBuses, UgFifoDeq#(Bit#(BurstRespSz))) burstResp;
  interface Output#(Bool) busy;
  interface ConditionalOutput#(Pair#(Pair#(Bit#(1), Index#(NumBuses)), Pair#(Index#(MaxBigI), Index#(MaxBigI)))) dataReq;
  interface Vector#(2, Vector#(NumBuses, ConditionalOutput_#(Bit#(PacketSz)))) dataResp;
  interface ConditionalOutput#(Size) recvSize;
  interface ConditionalOutput#(Pair#(Size, Index#(MaxBigK))) sendSize;
endinterface

module _MatrixMultiply(Tuple2#(MatrixMultiply_, MatrixMultiply)) ;
  Tuple2#(Vector#(NumBuses, UgFifoEnq_#(Bit#(HostSz))), Vector#(NumBuses, UgFifoEnq#(Bit#(HostSz)))) dataEnq_ <- replicateTupleM(_UgFifoEnq);
  Tuple2#(Vector#(NumBuses, UgFifoEnq_#(Pair#(RealAddr, Pair#(NumElems#(NumBuses), NumElems#(DataSz))))), Vector#(NumBuses, UgFifoEnq#(Pair#(RealAddr, Pair#(NumElems#(NumBuses), NumElems#(DataSz)))))) ctrlEnq_ <- replicateTupleM(_UgFifoEnq);
  Tuple2#(ConditionalOutput_#(Size), ConditionalOutput#(Size)) setSize_ <- _ConditionalOutput(True, True);
  Tuple2#(Vector#(NumBuses, UgFifoDeq_#(Bit#(BurstRespSz))), Vector#(NumBuses, UgFifoDeq#(Bit#(BurstRespSz)))) burstResp_ <- replicateTupleM(_UgFifoDeq);
  Tuple2#(Output_#(Bool), Output#(Bool)) busy_ <- _Output(True, True);
  Tuple2#(ConditionalOutput_#(Pair#(Pair#(Bit#(1), Index#(NumBuses)), Pair#(Index#(MaxBigI), Index#(MaxBigI)))), ConditionalOutput#(Pair#(Pair#(Bit#(1), Index#(NumBuses)), Pair#(Index#(MaxBigI), Index#(MaxBigI))))) dataReq_ <- _ConditionalOutput(True, True);
  Tuple2#(Vector#(2, Vector#(NumBuses, ConditionalOutput_#(Bit#(PacketSz)))), Vector#(2, Vector#(NumBuses, ConditionalOutput#(Bit#(PacketSz))))) dataResp_ <- replicateTupleM(replicateTupleM(_ConditionalOutput(True, True)));
  Tuple2#(ConditionalOutput_#(Size), ConditionalOutput#(Size)) recvSize_ <- _ConditionalOutput(True, True);
  Tuple2#(ConditionalOutput_#(Pair#(Size, Index#(MaxBigK))), ConditionalOutput#(Pair#(Size, Index#(MaxBigK)))) sendSize_ <- _ConditionalOutput(True, True);
  return tuple2(
    interface MatrixMultiply_;
      interface dataEnq = tpl_1(asIfc(dataEnq_));
      interface ctrlEnq = tpl_1(asIfc(ctrlEnq_));
      interface setSize = tpl_2(asIfc(setSize_));
      interface burstResp = tpl_1(asIfc(burstResp_));
      interface busy = tpl_1(asIfc(busy_));
      interface dataReq = tpl_1(asIfc(dataReq_));
      interface dataResp = tpl_2(asIfc(dataResp_));
      interface recvSize = tpl_1(asIfc(recvSize_));
      interface sendSize = tpl_1(asIfc(sendSize_));
    endinterface,
    interface MatrixMultiply;
      interface dataEnq = tpl_2(asIfc(dataEnq_));
      interface ctrlEnq = tpl_2(asIfc(ctrlEnq_));
      interface setSize = tpl_1(asIfc(setSize_));
      interface burstResp = tpl_2(asIfc(burstResp_));
      interface busy = tpl_2(asIfc(busy_));
      interface dataReq = tpl_2(asIfc(dataReq_));
      interface dataResp = tpl_1(asIfc(dataResp_));
      interface recvSize = tpl_2(asIfc(recvSize_));
      interface sendSize = tpl_2(asIfc(sendSize_));
    endinterface);
endmodule

instance Connectable#(MatrixMultiply, MatrixMultiply_) ;
  module mkConnection#(MatrixMultiply a, MatrixMultiply_ b)();
    mkConnection(asIfc(a.dataEnq), asIfc(b.dataEnq));
    mkConnection(asIfc(a.ctrlEnq), asIfc(b.ctrlEnq));
    mkConnection(asIfc(a.setSize), asIfc(b.setSize));
    mkConnection(asIfc(a.burstResp), asIfc(b.burstResp));
    mkConnection(asIfc(a.busy), asIfc(b.busy));
    mkConnection(asIfc(a.dataReq), asIfc(b.dataReq));
    mkConnection(asIfc(a.dataResp), asIfc(b.dataResp));
    mkConnection(asIfc(a.recvSize), asIfc(b.recvSize));
    mkConnection(asIfc(a.sendSize), asIfc(b.sendSize));
  endmodule
endinstance

instance Connectable#(MatrixMultiply_, MatrixMultiply) ;
  module mkConnection#(MatrixMultiply_ a, MatrixMultiply b)();
    mkConnection(asIfc(b), asIfc(a));
  endmodule
endinstance

(* synthesize *)
module mkMatrixMultiply(MatrixMultiply) ;
  Tuple2#(MatrixMultiply_, MatrixMultiply) mod_ <- _MatrixMultiply;

  Receiver receiver <- mkReceiver;
  Sender sender <- mkSender;
  FinalFifo finalFifo <- mkFinalFifo;
  Multiply mult <- mkMultiply;

  (* fire_when_enabled *) rule x0;
    (tpl_1(asIfc(mod_))).busy.write( sender.busy || receiver.busy);
    if((tpl_1(asIfc(mod_))).setSize.en)
    begin
      sender.setSize.write( (tpl_1(asIfc(mod_))).setSize);
      receiver.setSize.write( (tpl_1(asIfc(mod_))).setSize);
      finalFifo.setSize.write( (tpl_1(asIfc(mod_))).setSize);
    end
  endrule

  mkConnection(asIfc((tpl_1(asIfc(mod_))).dataReq), asIfc( receiver.dataReq));
  mkConnection(asIfc((tpl_1(asIfc(mod_))).dataResp), asIfc( receiver.dataResp));
  mkConnection(asIfc(receiver.toMult), asIfc( mult.toMult));

  mkConnection(asIfc(sender.fromMult), asIfc( mult.fromMult));
  mkConnection(asIfc(sender.dataDeq), asIfc( finalFifo.dataDeq));
  mkConnection(asIfc(sender.addrDeq), asIfc( finalFifo.addrDeq));

  mkConnection(asIfc((tpl_1(asIfc(mod_))).dataEnq), asIfc( finalFifo.dataEnq));
  mkConnection(asIfc((tpl_1(asIfc(mod_))).ctrlEnq), asIfc( finalFifo.ctrlEnq));

  mkConnection(asIfc((tpl_1(asIfc(mod_))).burstResp), asIfc( finalFifo.burstResp));

  mkConnection(asIfc(receiver.recvInd), asIfc( (tpl_1(asIfc(mod_))).recvSize));
  mkConnection(asIfc(sender.sendSize), asIfc( (tpl_1(asIfc(mod_))).sendSize));

  return tpl_2(asIfc(mod_));
endmodule

