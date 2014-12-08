(* always_ready *)
interface RegFileVerilog_#(numeric type size, type t);
  method t read(Bit#(TLog#(size)) addr);
  method Action write(Bit#(TLog#(size)) addr, t data);
endinterface

import "BVI" mkRegFileVerilogLoad =
module mkRegFileVerilogLoad#(Integer mode, String file)(RegFileVerilog_#(size, t)) provisos(Bits#(t, tSz));
  parameter width = valueOf(tSz);
  parameter n = valueOf(TLog#(size));
  parameter size = valueOf(size);
  parameter file = file;
  parameter mode = mode;

  method READ_RESP_READ read (READ_REQ_WRITE);
  method write(WRITE_INDEX_WRITE, WRITE_DATA_WRITE) enable(WRITE_EN_WRITE);

  schedule read CF (read, write);
  schedule write C write;

  default_clock ck(CLK);
  default_reset rt(RST_N) clocked_by(ck);

  path (READ_REQ_WRITE, READ_RESP_READ);
endmodule
