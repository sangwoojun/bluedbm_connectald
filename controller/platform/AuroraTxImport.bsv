package AuroraTxImport;

interface AuroraTxIfc;
	method Action send(Bit#(32) data);
	
	method Bit#(1) channel_up;
	method Bit#(1) lane_up;
	method Bit#(1) hard_err;
endinterface

(* always_enabled, always_ready *)
interface AuroraTx_Pins;
	(* prefix = "", result = "TXN" *)
	method Bit#(1) txn_out();
	(* prefix = "", result = "TXP" *)
	method Bit#(1) txp_out();
endinterface

interface AuroraTx;
	interface Clock aurora_clk;
	interface Reset aurora_rst;
	(*prefix = "" *)
	interface AuroraTx_Pins aurora;

	(*prefix = "" *)
	interface AuroraTxIfc user;
endinterface

import "BVI" aurora_TX_exdes =
module mkAuroraTx#(Clock gtx, Clock init, Reset rst) 
	(AuroraTx);

	default_clock no_clock;
	default_reset no_reset;
	
	input_clock (INIT_CLK_IN) = init;
	input_clock (GTPQ_CLK) = gtx;
	input_reset (RESET_N) = rst;

	output_clock aurora_clk(USER_CLK);
	output_reset aurora_rst(USER_RST_N) clocked_by (aurora_clk);

	interface AuroraTxIfc user;
		method TX_CHANNEL_UP channel_up;
		method TX_LANE_UP lane_up;
		method TX_HARD_ERR hard_err;
		method send(TX_DATA) enable(tx_en) ready(tx_rdy) clocked_by(aurora_clk) reset_by(aurora_rst);
	endinterface

	interface AuroraTx_Pins aurora;
		method TXN txn_out() reset_by(no_reset) clocked_by(gtx); 
		method TXP txp_out() reset_by(no_reset) clocked_by(gtx);
	endinterface

	schedule ( aurora_txn_out, aurora_txp_out ) CF ( aurora_txn_out, aurora_txp_out );

endmodule

endpackage: AuroraTxImport
