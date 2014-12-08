import Vector::*;
import HaskellLib::*;
import Connectable::*;
import Base::*;
import Primitive::*;
export MultiFifo::*;

import Library::*;
export Library::*;

import RegsFile::*;
export RegsFile::*;

interface MultiFifoEnq_#(numeric type n, numeric type enqsNum, type t);
  interface Output#(NumElems#(n)) numFreeSlots;
  interface Vector#(enqsNum, ConditionalOutput_#(t)) data;
endinterface

interface MultiFifoEnq#(numeric type n, numeric type enqsNum, type t);
  interface Output_#(NumElems#(n)) numFreeSlots;
  interface Vector#(enqsNum, ConditionalOutput#(t)) data;
endinterface

module _MultiFifoEnq(Tuple2#(MultiFifoEnq_#(n, enqsNum, t), MultiFifoEnq#(n, enqsNum, t))) provisos(Bits#(t, _sZt));
  Tuple2#(Output_#(NumElems#(n)), Output#(NumElems#(n))) numFreeSlots_ <- _Output(True, True);
  Tuple2#(Vector#(enqsNum, ConditionalOutput_#(t)), Vector#(enqsNum, ConditionalOutput#(t))) data_ <- replicateTupleM(_ConditionalOutput(True, True));
  return tuple2(
    interface MultiFifoEnq_;
      interface numFreeSlots = tpl_2(asIfc(numFreeSlots_));
      interface data = tpl_1(asIfc(data_));
    endinterface,
    interface MultiFifoEnq;
      interface numFreeSlots = tpl_1(asIfc(numFreeSlots_));
      interface data = tpl_2(asIfc(data_));
    endinterface);
endmodule

instance Connectable#(MultiFifoEnq#(n, enqsNum, t), MultiFifoEnq_#(n, enqsNum, t)) provisos(Bits#(t, _sZt));
  module mkConnection#(MultiFifoEnq#(n, enqsNum, t) a, MultiFifoEnq_#(n, enqsNum, t) b)();
    mkConnection(asIfc(a.numFreeSlots), asIfc(b.numFreeSlots));
    mkConnection(asIfc(a.data), asIfc(b.data));
  endmodule
endinstance

instance Connectable#(MultiFifoEnq_#(n, enqsNum, t), MultiFifoEnq#(n, enqsNum, t)) provisos(Bits#(t, _sZt));
  module mkConnection#(MultiFifoEnq_#(n, enqsNum, t) a, MultiFifoEnq#(n, enqsNum, t) b)();
    mkConnection(asIfc(b), asIfc(a));
  endmodule
endinstance

interface MultiFifoDeq_#(numeric type n, numeric type deqsNum, type t);
  interface Output#(NumElems#(n)) numFilledSlots;
  interface Vector#(deqsNum, ConditionalOutput#(t)) data;
  interface ConditionalOutput_#(NumElems#(n)) numDeqs;
endinterface

interface MultiFifoDeq#(numeric type n, numeric type deqsNum, type t);
  interface Output_#(NumElems#(n)) numFilledSlots;
  interface Vector#(deqsNum, ConditionalOutput_#(t)) data;
  interface ConditionalOutput#(NumElems#(n)) numDeqs;
endinterface

module _MultiFifoDeq(Tuple2#(MultiFifoDeq_#(n, deqsNum, t), MultiFifoDeq#(n, deqsNum, t))) provisos(Bits#(t, _sZt));
  Tuple2#(Output_#(NumElems#(n)), Output#(NumElems#(n))) numFilledSlots_ <- _Output(True, True);
  Tuple2#(Vector#(deqsNum, ConditionalOutput_#(t)), Vector#(deqsNum, ConditionalOutput#(t))) data_ <- replicateTupleM(_ConditionalOutput(True, True));
  Tuple2#(ConditionalOutput_#(NumElems#(n)), ConditionalOutput#(NumElems#(n))) numDeqs_ <- _ConditionalOutput(True, True);
  return tuple2(
    interface MultiFifoDeq_;
      interface numFilledSlots = tpl_2(asIfc(numFilledSlots_));
      interface data = tpl_2(asIfc(data_));
      interface numDeqs = tpl_1(asIfc(numDeqs_));
    endinterface,
    interface MultiFifoDeq;
      interface numFilledSlots = tpl_1(asIfc(numFilledSlots_));
      interface data = tpl_1(asIfc(data_));
      interface numDeqs = tpl_2(asIfc(numDeqs_));
    endinterface);
endmodule

instance Connectable#(MultiFifoDeq#(n, deqsNum, t), MultiFifoDeq_#(n, deqsNum, t)) provisos(Bits#(t, _sZt));
  module mkConnection#(MultiFifoDeq#(n, deqsNum, t) a, MultiFifoDeq_#(n, deqsNum, t) b)();
    mkConnection(asIfc(a.numFilledSlots), asIfc(b.numFilledSlots));
    mkConnection(asIfc(a.data), asIfc(b.data));
    mkConnection(asIfc(a.numDeqs), asIfc(b.numDeqs));
  endmodule
endinstance

instance Connectable#(MultiFifoDeq_#(n, deqsNum, t), MultiFifoDeq#(n, deqsNum, t)) provisos(Bits#(t, _sZt));
  module mkConnection#(MultiFifoDeq_#(n, deqsNum, t) a, MultiFifoDeq#(n, deqsNum, t) b)();
    mkConnection(asIfc(b), asIfc(a));
  endmodule
endinstance

interface MultiFifo_#(numeric type n, numeric type enqsNum, numeric type deqsNum, type t);
  interface MultiFifoEnq#(n, enqsNum, t) enq;
  interface MultiFifoDeq#(n, deqsNum, t) deq;
  interface OutputPulse clear;
endinterface

interface MultiFifo#(numeric type n, numeric type enqsNum, numeric type deqsNum, type t);
  interface MultiFifoEnq_#(n, enqsNum, t) enq;
  interface MultiFifoDeq_#(n, deqsNum, t) deq;
  interface OutputPulse_ clear;
endinterface

module _MultiFifo(Tuple2#(MultiFifo_#(n, enqsNum, deqsNum, t), MultiFifo#(n, enqsNum, deqsNum, t))) provisos(Bits#(t, _sZt));
  Tuple2#(MultiFifoEnq_#(n, enqsNum, t), MultiFifoEnq#(n, enqsNum, t)) enq_ <- _MultiFifoEnq;
  Tuple2#(MultiFifoDeq_#(n, deqsNum, t), MultiFifoDeq#(n, deqsNum, t)) deq_ <- _MultiFifoDeq;
  Tuple2#(OutputPulse_, OutputPulse) clear_ <- _OutputPulse(True, True);
  return tuple2(
    interface MultiFifo_;
      interface enq = tpl_2(asIfc(enq_));
      interface deq = tpl_2(asIfc(deq_));
      interface clear = tpl_2(asIfc(clear_));
    endinterface,
    interface MultiFifo;
      interface enq = tpl_1(asIfc(enq_));
      interface deq = tpl_1(asIfc(deq_));
      interface clear = tpl_1(asIfc(clear_));
    endinterface);
endmodule

instance Connectable#(MultiFifo#(n, enqsNum, deqsNum, t), MultiFifo_#(n, enqsNum, deqsNum, t)) provisos(Bits#(t, _sZt));
  module mkConnection#(MultiFifo#(n, enqsNum, deqsNum, t) a, MultiFifo_#(n, enqsNum, deqsNum, t) b)();
    mkConnection(asIfc(a.enq), asIfc(b.enq));
    mkConnection(asIfc(a.deq), asIfc(b.deq));
    mkConnection(asIfc(a.clear), asIfc(b.clear));
  endmodule
endinstance

instance Connectable#(MultiFifo_#(n, enqsNum, deqsNum, t), MultiFifo#(n, enqsNum, deqsNum, t)) provisos(Bits#(t, _sZt));
  module mkConnection#(MultiFifo_#(n, enqsNum, deqsNum, t) a, MultiFifo#(n, enqsNum, deqsNum, t) b)();
    mkConnection(asIfc(b), asIfc(a));
  endmodule
endinstance

module mkMultiFifo(MultiFifo#(n, enqsNum, deqsNum, t)) provisos(Bits#(t, tSz), Add#(a__, TLog#(n), TLog#(TAdd#(n, 1))));
  Tuple2#(MultiFifo_#(n, enqsNum, deqsNum, t), MultiFifo#(n, enqsNum, deqsNum, t)) mod_ <- _MultiFifo;

  RegFile#(deqsNum, enqsNum, n, t) rf <- mkRegFileU;
  Reg#(Index#(n))                head <- mkReg(0);
  Reg#(Index#(n))                tail <- mkReg(0);
  Reg#(NumElems#(n))         numElems <- mkReg(0);

  (* fire_when_enabled *) rule a;
    NumElems#(n) numEnqs = 0;
    for(Integer i = 0; i < valueOf(enqsNum); i = i + 1)
      if((tpl_1(asIfc(mod_))).enq.data[i].en)
      begin
        rf.write[i].write( Pair{fst: Index#(n)'(moduloPlus(valueOf(n), numEnqs, head)), snd: (tpl_1(asIfc(mod_))).enq.data[i]});
        numEnqs = numEnqs + 1;
      end
    head <= (tpl_1(asIfc(mod_))).clear? 0: moduloPlus(valueOf(n), numEnqs, head);

    (tpl_1(asIfc(mod_))).enq.numFreeSlots.write( fromInteger(valueOf(n)) - numElems);

    NumElems#(n) numFilledSlots = numElems;
    (tpl_1(asIfc(mod_))).deq.numFilledSlots.write( numFilledSlots);

    for(Integer i = 0; i < valueOf(deqsNum); i = i + 1)
      if(fromInteger(i) < numFilledSlots)
      begin
        rf.read[i].req.write( Index#(n)'(moduloPlus(valueOf(n), fromInteger(i), tail)));
        (tpl_1(asIfc(mod_))).deq.data[i].write( rf.read[i].resp);
      end
    NumElems#(n) numDeqs = 0;
    if((tpl_1(asIfc(mod_))).deq.numDeqs.en)
      numDeqs = (tpl_1(asIfc(mod_))).deq.numDeqs;
    tail <= (tpl_1(asIfc(mod_))).clear? 0: moduloPlus(valueOf(n), numDeqs, tail);

    numElems <= (tpl_1(asIfc(mod_))).clear? 0: numElems + (numEnqs - numDeqs);
  endrule

  return tpl_2(asIfc(mod_));
endmodule

module mkMultiLFifo(MultiFifo#(n, enqsNum, deqsNum, t)) provisos(Bits#(t, tSz), Add#(a__, TLog#(n), TLog#(TAdd#(n, 1))));
  Tuple2#(MultiFifo_#(n, enqsNum, deqsNum, t), MultiFifo#(n, enqsNum, deqsNum, t)) mod_ <- _MultiFifo;

  RegFile#(deqsNum, enqsNum, n, t) rf <- mkRegFileU;
  Reg#(Index#(n))                head <- mkReg(0);
  Reg#(Index#(n))                tail <- mkReg(0);
  Reg#(NumElems#(n))         numElems <- mkReg(0);

  (* fire_when_enabled *) rule a;
    NumElems#(n) numEnqs = 0;
    for(Integer i = 0; i < valueOf(enqsNum); i = i + 1)
      if((tpl_1(asIfc(mod_))).enq.data[i].en)
      begin
        rf.write[i].write( Pair{fst: Index#(n)'(moduloPlus(valueOf(n), numEnqs, head)), snd: (tpl_1(asIfc(mod_))).enq.data[i]});
        numEnqs = numEnqs + 1;
      end
    head <= (tpl_1(asIfc(mod_))).clear? 0: moduloPlus(valueOf(n), numEnqs, head);

    (tpl_1(asIfc(mod_))).enq.numFreeSlots.write( fromInteger(valueOf(n)) - numElems + (tpl_1(asIfc(mod_))).deq.numDeqs);

    NumElems#(n) numFilledSlots = numElems;
    (tpl_1(asIfc(mod_))).deq.numFilledSlots.write( numFilledSlots);

    for(Integer i = 0; i < valueOf(deqsNum); i = i + 1)
      if(fromInteger(i) < numFilledSlots)
      begin
        rf.read[i].req.write( Index#(n)'(moduloPlus(valueOf(n), fromInteger(i), tail)));
        (tpl_1(asIfc(mod_))).deq.data[i].write( rf.read[i].resp);
      end
    NumElems#(n) numDeqs = 0;
    if((tpl_1(asIfc(mod_))).deq.numDeqs.en)
      numDeqs = (tpl_1(asIfc(mod_))).deq.numDeqs;
    tail <= (tpl_1(asIfc(mod_))).clear? 0: moduloPlus(valueOf(n), numDeqs, tail);

    numElems <= (tpl_1(asIfc(mod_))).clear? 0: numElems + (numEnqs - numDeqs);
  endrule

  return tpl_2(asIfc(mod_));
endmodule

module mkMultiBypassFifo(MultiFifo#(n, enqsNum, deqsNum, t)) provisos(Bits#(t, tSz), Add#(a__, TLog#(n), TLog#(TAdd#(n, 1))));
  Tuple2#(MultiFifo_#(n, enqsNum, deqsNum, t), MultiFifo#(n, enqsNum, deqsNum, t)) mod_ <- _MultiFifo;

  RegFile#(deqsNum, enqsNum, n, t) rf <- mkRegFileU;
  Reg#(Index#(n))                head <- mkReg(0);
  Reg#(Index#(n))                tail <- mkReg(0);
  Reg#(NumElems#(n))         numElems <- mkReg(0);

  (* fire_when_enabled *) rule a;
    NumElems#(n) numEnqs = 0;
    for(Integer i = 0; i < valueOf(enqsNum); i = i + 1)
      if((tpl_1(asIfc(mod_))).enq.data[i].en)
      begin
        rf.write[i].write( Pair{fst: Index#(n)'(moduloPlus(valueOf(n), numEnqs, head)), snd: (tpl_1(asIfc(mod_))).enq.data[i]});
        numEnqs = numEnqs + 1;
      end
    head <= (tpl_1(asIfc(mod_))).clear? 0: moduloPlus(valueOf(n), numEnqs, head);

    (tpl_1(asIfc(mod_))).enq.numFreeSlots.write( fromInteger(valueOf(n)) - numElems);

    NumElems#(n) numFilledSlots = numElems + numEnqs;
    (tpl_1(asIfc(mod_))).deq.numFilledSlots.write( numFilledSlots);

    for(Integer i = 0; i < valueOf(deqsNum); i = i + 1)
      if(fromInteger(i) < numFilledSlots)
      begin
        if(fromInteger(i) < numElems)
        begin
          rf.read[i].req.write( Index#(n)'(moduloPlus(valueOf(n), fromInteger(i), tail)));
          (tpl_1(asIfc(mod_))).deq.data[i].write( rf.read[i].resp);
        end
        else
          (tpl_1(asIfc(mod_))).deq.data[i].write( (tpl_1(asIfc(mod_))).enq.data[fromInteger(i) - numElems]);
      end
    NumElems#(n) numDeqs = 0;
    if((tpl_1(asIfc(mod_))).deq.numDeqs.en)
      numDeqs = (tpl_1(asIfc(mod_))).deq.numDeqs;
    tail <= (tpl_1(asIfc(mod_))).clear? 0: moduloPlus(valueOf(n), numDeqs, tail);

    numElems <= (tpl_1(asIfc(mod_))).clear? 0: numElems + (numEnqs - numDeqs);
  endrule

  return tpl_2(asIfc(mod_));
endmodule

