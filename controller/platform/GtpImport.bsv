package GtpImport;

(* always_enabled, always_ready *)
interface Gtp_Pins;
	(* prefix = "", result = "RXN" *)
	method Action rxn_in(Bit#(1) rxn_i);
	(* prefix = "", result = "RXP" *)
	method Action rxp_in(Bit#(1) rxp_i);

	(* prefix = "", result = "TXN" *)
	method Bit#(1) txn_out();
	(* prefix = "", result = "TXP" *)
	method Bit#(1) txp_out();
endinterface

(* always_enabled, always_ready *)
interface GtpUserIfc;
	method Action send(Bit#(16) tx);
	method Bit#(16) receive();
endinterface

interface GtpIfc;
	interface Clock user_clk;
	(* prefix = "" *)
	interface GtpUserIfc user;
	(* prefix = "" *)
	interface Gtp_Pins gtp_pins;
endinterface

import "BVI" gtp_raw0_exdes =
module mkGtpRawImport0#(Clock gtx_p, Clock gtx_n, Clock drp, Reset tx_rst, Reset rx_rst, Reset pll_rst) (GtpIfc);
default_clock no_clock;
default_reset no_reset;

input_clock (Q0_CLK1_GTREFCLK_PAD_N_IN) = gtx_n;
input_clock (Q0_CLK1_GTREFCLK_PAD_P_IN) = gtx_p;

input_clock (DRP_CLK_IN) = drp;

//input_reset (GTTX_RESET_IN) = tx_rst;
//input_reset (GTRX_RESET_IN) = rx_rst;
//input_reset (PLL0_RESET_IN) = pll_rst;

output_clock user_clk(gt0_txusrclk_i);

	interface GtpUserIfc user;
		method send(gt0_txdata_i) enable((*inhigh*) send_en) clocked_by(user_clk) reset_by(no_reset);
		method gt0_rxdata_i_i receive() clocked_by(user_clk) reset_by(no_reset);
	endinterface
	
	interface Gtp_Pins gtp_pins;
		method rxn_in(RXN_IN) enable((*inhigh*) rx_n_en) reset_by(no_reset) clocked_by(gtx_p);
		method rxp_in(RXP_IN) enable((*inhigh*) rx_p_en) reset_by(no_reset) clocked_by(gtx_p);
		method TXN_OUT txn_out() reset_by(no_reset) clocked_by(gtx_p); 
		method TXP_OUT txp_out() reset_by(no_reset) clocked_by(gtx_p);
	endinterface

	schedule (gtp_pins_rxn_in, gtp_pins_rxp_in, gtp_pins_txn_out, gtp_pins_txp_out, user_send, user_receive) CF (gtp_pins_rxn_in, gtp_pins_rxp_in, gtp_pins_txn_out, gtp_pins_txp_out, user_send, user_receive);
endmodule

endpackage: GtpImport
