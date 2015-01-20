import Vector::*;
import HaskellLib::*;
import Connectable::*;
import Base::*;
import Primitive::*;
export Fifo::*;

import Bram::*;
export Bram::*;

import Library::*;
export Library::*;

import MultiFifo::*;
export MultiFifo::*;

interface UgFifoEnq_#(type t);
  interface Output#(Bool) notFull;
  interface ConditionalOutput_#(t) enq;
endinterface

interface UgFifoEnq#(type t);
  interface Output_#(Bool) notFull;
  interface ConditionalOutput#(t) enq;
endinterface

module _UgFifoEnq(Tuple2#(UgFifoEnq_#(t), UgFifoEnq#(t))) provisos(Bits#(t, _sZt));
  Tuple2#(Output_#(Bool), Output#(Bool)) notFull_ <- _Output(True, True);
  Tuple2#(ConditionalOutput_#(t), ConditionalOutput#(t)) enq_ <- _ConditionalOutput(True, True);
  return tuple2(
    interface UgFifoEnq_;
      interface notFull = tpl_2(asIfc(notFull_));
      interface enq = tpl_1(asIfc(enq_));
    endinterface,
    interface UgFifoEnq;
      interface notFull = tpl_1(asIfc(notFull_));
      interface enq = tpl_2(asIfc(enq_));
    endinterface);
endmodule

instance Connectable#(UgFifoEnq#(t), UgFifoEnq_#(t)) provisos(Bits#(t, _sZt));
  module mkConnection#(UgFifoEnq#(t) a, UgFifoEnq_#(t) b)();
    mkConnection(asIfc(a.notFull), asIfc(b.notFull));
    mkConnection(asIfc(a.enq), asIfc(b.enq));
  endmodule
endinstance

instance Connectable#(UgFifoEnq_#(t), UgFifoEnq#(t)) provisos(Bits#(t, _sZt));
  module mkConnection#(UgFifoEnq_#(t) a, UgFifoEnq#(t) b)();
    mkConnection(asIfc(b), asIfc(a));
  endmodule
endinstance

interface UgFifoDeq_#(type t);
  interface Output#(Bool) notEmpty;
  interface Output#(t) first;
  interface OutputPulse_ deq;
endinterface

interface UgFifoDeq#(type t);
  interface Output_#(Bool) notEmpty;
  interface Output_#(t) first;
  interface OutputPulse deq;
endinterface

module _UgFifoDeq(Tuple2#(UgFifoDeq_#(t), UgFifoDeq#(t))) provisos(Bits#(t, _sZt));
  Tuple2#(Output_#(Bool), Output#(Bool)) notEmpty_ <- _Output(True, True);
  Tuple2#(Output_#(t), Output#(t)) first_ <- _Output(True, True);
  Tuple2#(OutputPulse_, OutputPulse) deq_ <- _OutputPulse(True, True);
  return tuple2(
    interface UgFifoDeq_;
      interface notEmpty = tpl_2(asIfc(notEmpty_));
      interface first = tpl_2(asIfc(first_));
      interface deq = tpl_1(asIfc(deq_));
    endinterface,
    interface UgFifoDeq;
      interface notEmpty = tpl_1(asIfc(notEmpty_));
      interface first = tpl_1(asIfc(first_));
      interface deq = tpl_2(asIfc(deq_));
    endinterface);
endmodule

instance Connectable#(UgFifoDeq#(t), UgFifoDeq_#(t)) provisos(Bits#(t, _sZt));
  module mkConnection#(UgFifoDeq#(t) a, UgFifoDeq_#(t) b)();
    mkConnection(asIfc(a.notEmpty), asIfc(b.notEmpty));
    mkConnection(asIfc(a.first), asIfc(b.first));
    mkConnection(asIfc(a.deq), asIfc(b.deq));
  endmodule
endinstance

instance Connectable#(UgFifoDeq_#(t), UgFifoDeq#(t)) provisos(Bits#(t, _sZt));
  module mkConnection#(UgFifoDeq_#(t) a, UgFifoDeq#(t) b)();
    mkConnection(asIfc(b), asIfc(a));
  endmodule
endinstance

interface UgFifo_#(numeric type n, type t);
  interface UgFifoEnq#(t) enq;
  interface UgFifoDeq#(t) deq;
  interface Output_#(NumElems#(n)) numFilled;
  interface OutputPulse clear;
  interface OutputPulse clearDeq;
endinterface

interface UgFifo#(numeric type n, type t);
  interface UgFifoEnq_#(t) enq;
  interface UgFifoDeq_#(t) deq;
  interface Output#(NumElems#(n)) numFilled;
  interface OutputPulse_ clear;
  interface OutputPulse_ clearDeq;
endinterface

module _UgFifo(Tuple2#(UgFifo_#(n, t), UgFifo#(n, t))) provisos(Bits#(t, _sZt));
  Tuple2#(UgFifoEnq_#(t), UgFifoEnq#(t)) enq_ <- _UgFifoEnq;
  Tuple2#(UgFifoDeq_#(t), UgFifoDeq#(t)) deq_ <- _UgFifoDeq;
  Tuple2#(Output_#(NumElems#(n)), Output#(NumElems#(n))) numFilled_ <- _Output(True, True);
  Tuple2#(OutputPulse_, OutputPulse) clear_ <- _OutputPulse(True, True);
  Tuple2#(OutputPulse_, OutputPulse) clearDeq_ <- _OutputPulse(True, True);
  return tuple2(
    interface UgFifo_;
      interface enq = tpl_2(asIfc(enq_));
      interface deq = tpl_2(asIfc(deq_));
      interface numFilled = tpl_1(asIfc(numFilled_));
      interface clear = tpl_2(asIfc(clear_));
      interface clearDeq = tpl_2(asIfc(clearDeq_));
    endinterface,
    interface UgFifo;
      interface enq = tpl_1(asIfc(enq_));
      interface deq = tpl_1(asIfc(deq_));
      interface numFilled = tpl_2(asIfc(numFilled_));
      interface clear = tpl_1(asIfc(clear_));
      interface clearDeq = tpl_1(asIfc(clearDeq_));
    endinterface);
endmodule

instance Connectable#(UgFifo#(n, t), UgFifo_#(n, t)) provisos(Bits#(t, _sZt));
  module mkConnection#(UgFifo#(n, t) a, UgFifo_#(n, t) b)();
    mkConnection(asIfc(a.enq), asIfc(b.enq));
    mkConnection(asIfc(a.deq), asIfc(b.deq));
    mkConnection(asIfc(a.numFilled), asIfc(b.numFilled));
    mkConnection(asIfc(a.clear), asIfc(b.clear));
    mkConnection(asIfc(a.clearDeq), asIfc(b.clearDeq));
  endmodule
endinstance

instance Connectable#(UgFifo_#(n, t), UgFifo#(n, t)) provisos(Bits#(t, _sZt));
  module mkConnection#(UgFifo_#(n, t) a, UgFifo#(n, t) b)();
    mkConnection(asIfc(b), asIfc(a));
  endmodule
endinstance

module mkGenericUgFifo#(function _m__#(MultiFifo#(n, 1, 1, t)) mkF)(UgFifo#(n, t)) provisos(Bits#(t, tSz), Add#(a__, TLog#(n), TLog#(TAdd#(n, 1))));
  Tuple2#(UgFifo_#(n, t), UgFifo#(n, t)) mod_ <- _UgFifo;

  MultiFifo#(n, 1, 1, t) f <- mkF;

  (* fire_when_enabled *) rule a;
    (tpl_1(asIfc(mod_))).enq.notFull.write( f.enq.numFreeSlots > 0);
    (tpl_1(asIfc(mod_))).deq.notEmpty.write( f.deq.numFilledSlots > 0);
    f.deq.numDeqs.write( (tpl_1(asIfc(mod_))).deq.deq? 1: 0);
    (tpl_1(asIfc(mod_))).deq.first.write( f.deq.data[0]);
    (tpl_1(asIfc(mod_))).numFilled.write( f.deq.numFilledSlots);
    if((tpl_1(asIfc(mod_))).clear)
      f.clear;
  endrule

  mkConnection(asIfc(f.enq.data[0]), asIfc( (tpl_1(asIfc(mod_))).enq.enq));

  return tpl_2(asIfc(mod_));
endmodule


module mkLUgFifo(UgFifo#(n, t))provisos(Bits#(t, tSz), Add#(a__, TLog#(n), TLog#(TAdd#(n, 1))));
  UgFifo#(n, t) mod_ <- mkGenericUgFifo(mkMultiLFifo);
  return mod_;
endmodule


module mkUgFifo(UgFifo#(n, t))provisos(Bits#(t, tSz), Add#(a__, TLog#(n), TLog#(TAdd#(n, 1))));
  UgFifo#(n, t) mod_ <- mkGenericUgFifo(mkMultiFifo);
  return mod_;
endmodule


module mkBypassUgFifo(UgFifo#(n, t))provisos(Bits#(t, tSz), Add#(a__, TLog#(n), TLog#(TAdd#(n, 1))));
  UgFifo#(n, t) mod_ <- mkGenericUgFifo(mkMultiBypassFifo);
  return mod_;
endmodule

module mkBramFifo(UgFifo#(n, t)) provisos(Bits#(t, tSz), Add#(1, sth, n), Add#(a__, TLog#(n), TLog#(TAdd#(n, 1))), Add#(b__, 1, TLog#(TAdd#(n, 1))));
  Tuple2#(UgFifo_#(n, t), UgFifo#(n, t)) mod_ <- _UgFifo;

  Bram#(1, 1, n, t)        rf <- mkBramU;
  Reg#(Index#(n))        head <- mkReg(0);
  Reg#(Index#(n))        tail <- mkReg(moduloPlus(valueOf(n), 1, 0));
  Reg#(NumElems#(n)) numElems <- mkReg(0);
  Reg#(Bool)          reqSent <- mkReg(False);
  Reg#(t)             tailVal <- mkRegU;

  (* fire_when_enabled *) rule a;
    NumElems#(n) numEnqs = zeroExtend(pack((tpl_1(asIfc(mod_))).enq.enq.en));
    NumElems#(n) numDeqs = zeroExtend(pack((tpl_1(asIfc(mod_))).deq.deq));

    (tpl_1(asIfc(mod_))).enq.notFull.write( fromInteger(valueOf(n)) > numElems);
    (tpl_1(asIfc(mod_))).deq.notEmpty.write( numElems > 0);

    rf.write[0].write( Pair{fst: Index#(n)'(head), snd: (tpl_1(asIfc(mod_))).enq.enq});

    head <= (tpl_1(asIfc(mod_))).clear? 0 : moduloPlus(valueOf(n), numEnqs, head);
    tail <= (tpl_1(asIfc(mod_))).clear || (tpl_1(asIfc(mod_))).clearDeq? (moduloPlus(valueOf(n), 1, 0)) : moduloPlus(valueOf(n), numDeqs, tail);
    
    numElems <= (tpl_1(asIfc(mod_))).clear? 0 : numElems + (numEnqs - numDeqs);
    reqSent <= (tpl_1(asIfc(mod_))).deq.deq || (tpl_1(asIfc(mod_))).clearDeq;

    rf.read[0].req.write( (tpl_1(asIfc(mod_))).deq.deq? Index#(n)'(tail) : 0);

    t deqVal =
      reqSent ?
        rf.read[0].resp :
        tailVal;

    t newTailVal =
      (tpl_1(asIfc(mod_))).enq.enq.en && numElems == 0 ?
        (tpl_1(asIfc(mod_))).enq.enq :
        deqVal;

    (tpl_1(asIfc(mod_))).deq.first.write( deqVal);
    tailVal <= newTailVal;

    (tpl_1(asIfc(mod_))).numFilled.write( numElems);
  endrule

  return tpl_2(asIfc(mod_));
endmodule

