package IlaImport;
(* always_enabled, always_ready *)
interface IlaImportIfc;
	method Action probe(Bit#(64));
endinterface

import "BVI" ila_7series =
module mkIla#(Clock clk) (IlaImportIfc);
	default_clock no_clock;
	default_reset no_reset;

	input_clock (clk) = clk;

	method probe(probe0) enable(probe_en) reset_by (no_reset) clocked_by(clk);
endmodule
endpackage: IlaImport
