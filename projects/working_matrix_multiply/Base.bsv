(* always_ready *)
interface Wire#(type t);
  method Action write(t x);
  method t _read;
endinterface

(* always_ready *)
interface Pulse;
  method Action send;
  method Bool _read;
endinterface

(* always_ready *)
interface Reg#(type t);
  method t _read;
  method Action _write(t d);
endinterface

import "BVI" mkWire =
module mkWire(Wire#(t)) provisos(Bits#(t, tSz));
  parameter width = valueOf(tSz);
  method OUT_READ _read clocked_by(no_clock);
  method write(IN_WRITE) enable(IN_EN_WRITE);
  schedule _read CF (_read, write);
  schedule write C write;
  default_clock ck();
  default_reset no_reset;
  path(IN_WRITE, OUT_READ);
endmodule

import "BVI" mkPULSE =
module mkPulse(Pulse);
  method OUT_READ _read clocked_by(no_clock);
  method send() enable(IN_EN_WRITE);
  schedule _read CF (_read, send);
  schedule send C send;
  default_clock ck();
  default_reset no_reset;
  path(OUT_READ, IN_EN_WRITE);
  path(IN_EN_WRITE, OUT_READ);
endmodule

import "BVI" mkREG =
module mkReg#(t init)(Reg#(t)) provisos(Bits#(t, tSz));
  parameter width = valueOf(tSz);
  parameter init = pack(init);
  method OUT_READ _read;
  method _write (IN_WRITE) enable(IN_EN_WRITE);
  schedule _read CF (_read, _write);
  schedule _write C _write;
  default_clock ck(CLK);
  default_reset rt(RST_N) clocked_by (ck);
endmodule

import "BVI" mkREGU =
module mkRegU(Reg#(t)) provisos(Bits#(t, tSz));
  parameter width = valueOf(tSz);
  method OUT_READ _read;
  method _write (IN_WRITE) enable(IN_EN_WRITE);
  schedule _read CF (_read, _write);
  schedule _write C _write;
  default_clock ck(CLK);
  default_reset rt(RST_N) clocked_by (ck);
endmodule
