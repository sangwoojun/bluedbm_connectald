import Vector::*;

(* always_ready *)
interface Rand32;
  method Action req;
  method Bit#(32) resp;
endinterface

import "BVI" mkRand32 =
module mkRand32#(Bit#(32) seed)(Rand32);
  parameter seed = seed;
  method req() enable(REQ_WRITE);
  method RESP_READ resp;
  default_clock ck(CLK);
  default_reset no_reset;
  schedule resp CF (req, resp);
  schedule req CF req;
  path(REQ_WRITE, RESP_READ);
endmodule
