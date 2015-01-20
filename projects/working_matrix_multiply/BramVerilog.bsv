(* always_ready *)
interface BramVerilog_#(numeric type size, type t);
  method Action readReq(Bit#(TLog#(size)) addr);
  method t readResp;
  method Action write(Bit#(TLog#(size)) addr, t data);
endinterface

import "BVI" mkBramVerilog =
module mkBramVerilog(BramVerilog_#(size, t)) provisos(Bits#(t, tSz));
  parameter width = valueOf(tSz);
  parameter n = valueOf(TLog#(size));
  parameter size = valueOf(size);

  method readReq (READ_REQ_WRITE) enable(READ_EN_WRITE);
  method READ_RESP_READ readResp;
  method write(WRITE_INDEX_WRITE, WRITE_DATA_WRITE) enable(WRITE_EN_WRITE);

  schedule readReq C readReq;
  schedule readReq CF (readResp, write);
  schedule readResp CF (readResp, write);
  schedule write C write;

  default_clock ck(CLK);
  default_reset rt(RST_N) clocked_by(ck);
endmodule
