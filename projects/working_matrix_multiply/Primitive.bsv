import Base::*;
import Connectable::*;
import Vector::*;

typedef struct {
  t1 fst;
  t2 snd;
} Pair#(type t1, type t2) deriving (Bits, Eq);

(* always_enabled *)
interface Output_#(type t);
  (* always_enabled, prefix = "" *) method Action write((* port = "WRITE" *)t x);
endinterface

(* always_ready *)
interface Output#(type t);
  (* result = "READ" *) method t _read;
endinterface

instance Connectable#(Output_#(t), Output#(t));
  module mkConnection#(Output_#(t) a, Output#(t) b)();
    rule c1;
      a.write(b);
    endrule
  endmodule
endinstance

instance Connectable#(Output#(t), Output_#(t));
  module mkConnection#(Output#(t) a, Output_#(t) b)();
    mkConnection(asIfc(b), asIfc(a));
  endmodule
endinstance

module _Output#(Bool g1, Bool g2)(Tuple2#(Output_#(t), Output#(t))) provisos(Bits#(t, tSz));
  Wire#(t) dataLocal <- mkWire;

  return tuple2(
    interface Output_;
      method Action write(t x) if(g1);
        dataLocal.write(x);
      endmethod
    endinterface,

    interface Output;
      method t _read if(g2);
        return dataLocal;
      endmethod
    endinterface);
endmodule

(* always_ready *)
interface OutputPulse_;
  (* enable = "WRITE" *) method Action _read;
endinterface

typedef Output#(Bool) OutputPulse;

instance Connectable#(OutputPulse_, OutputPulse);
  module mkConnection#(OutputPulse_ a, OutputPulse b)();
    rule c3;
      if(b)
       a;
    endrule
  endmodule
endinstance

instance Connectable#(OutputPulse, OutputPulse_);
  module mkConnection#(OutputPulse a, OutputPulse_ b)();
    mkConnection(asIfc(b), asIfc(a));
  endmodule
endinstance

module _OutputPulse#(Bool g1, Bool g2)(Tuple2#(OutputPulse_, OutputPulse));
  Pulse dataLocal <- mkPulse;

  return tuple2(
    interface OutputPulse_;
      method Action _read if(g1);
        dataLocal.send;
      endmethod
    endinterface,

    interface OutputPulse;
      method Bool _read if(g2);
        return dataLocal;
      endmethod
    endinterface);
endmodule

(* always_ready *)
interface ConditionalOutput_#(type t);
  (* prefix = "", enable = "EN_WRITE" *) method Action write((* port = "WRITE" *)t x);
endinterface

(* always_ready *)
interface ConditionalOutput#(type t);
  (* result = "READ" *) method t _read;
  (* result = "EN_READ" *) method Bool en;
endinterface

instance Connectable#(ConditionalOutput_#(t), ConditionalOutput#(t));
  module mkConnection#(ConditionalOutput_#(t) a, ConditionalOutput#(t) b)();
    rule c1;
      if(b.en)
        a.write(b);
    endrule
  endmodule
endinstance

instance Connectable#(ConditionalOutput#(t), ConditionalOutput_#(t));
  module mkConnection#(ConditionalOutput#(t) a, ConditionalOutput_#(t) b)();
    mkConnection(asIfc(b), asIfc(a));
  endmodule
endinstance

module _ConditionalOutput#(Bool g1, Bool g2)(Tuple2#(ConditionalOutput_#(t), ConditionalOutput#(t))) provisos(Bits#(t, tSz));
  Wire#(t) dataLocal <- mkWire;
  Pulse enLocal <- mkPulse;

  return tuple2(
    interface ConditionalOutput_;
      method Action write(t x) if(g1);
        dataLocal.write(x);
        enLocal.send;
      endmethod
    endinterface,

    interface ConditionalOutput;
      method t _read if(g2);
        return dataLocal;
      endmethod

      method Bool en if(g2);
        return enLocal;
      endmethod
    endinterface);
endmodule
