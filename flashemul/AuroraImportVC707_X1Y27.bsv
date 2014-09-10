
package AuroraImportVC707_X1Y27;

import Clocks :: *;
import AuroraImportVC707::*;

import "BVI" aurora_X1Y27_exdes =
//module mkAuroraImport#(Clock gtx_clk_p, Clock gtx_clk_n, Clock init_clk, Reset init_rst_n) (Aurora_V7);
module mkAuroraImport_X1Y27#(Clock gtx_clk_in, Clock init_clk, Reset init_rst_n, Clock qpll_clk, Clock qpll_refclk) (Aurora_V7);
	default_clock no_clock;
	default_reset no_reset;

	input_clock (INIT_CLK_IN) = init_clk;
	input_reset (RESET_N) = init_rst_n;

	input_clock (QPLL_CLK) = qpll_clk;
	input_clock (QPLL_REFCLK) = qpll_refclk;
	
	output_clock aurora_clk(USER_CLK);
	output_reset aurora_rst(USER_RST_N) clocked_by (aurora_clk);

	input_clock (GTXQ_CLK) = gtx_clk_in;
	

	interface Aurora_Pins_VC707 aurora;
		method rxn_in(RXN) enable((*inhigh*) rx_n_en) reset_by(no_reset) clocked_by(gtx_clk_in);
		method rxp_in(RXP) enable((*inhigh*) rx_p_en) reset_by(no_reset) clocked_by(gtx_clk_in);
		method TXN txn_out() reset_by(no_reset) clocked_by(gtx_clk_in); 
		method TXP txp_out() reset_by(no_reset) clocked_by(gtx_clk_in);

	endinterface

	interface AuroraControllerIfc user;
		output_reset aurora_rst_n(USER_RST) clocked_by (aurora_clk);

		method CHANNEL_UP channel_up;
		method LANE_UP lane_up;
		method HARD_ERR hard_err;
		method SOFT_ERR soft_err;
		method DATA_ERR_COUNT data_err_count;

		method send(TX_DATA) enable(tx_en) ready(tx_rdy) clocked_by(aurora_clk) reset_by(aurora_rst);
		method RX_DATA receive() enable((*inhigh*) rx_en) ready(rx_rdy) clocked_by(aurora_clk) reset_by(aurora_rst);
	endinterface
	
	schedule (aurora_rxn_in, aurora_rxp_in, aurora_txn_out, aurora_txp_out, user_channel_up, user_lane_up, user_hard_err, user_soft_err, user_data_err_count) CF 
	(aurora_rxn_in, aurora_rxp_in, aurora_txn_out, aurora_txp_out, user_channel_up, user_lane_up, user_hard_err, user_soft_err, user_data_err_count);
	schedule (user_send) CF (aurora_rxn_in, aurora_rxp_in, aurora_txn_out, aurora_txp_out, user_channel_up, user_lane_up, user_hard_err, user_soft_err, user_data_err_count);

	schedule (user_receive) CF (aurora_rxn_in, aurora_rxp_in, aurora_txn_out, aurora_txp_out, user_channel_up, user_lane_up, user_hard_err, user_soft_err, user_data_err_count);

	schedule (user_receive) SB (user_send);
	schedule (user_send) C (user_send);
	schedule (user_receive) C (user_receive);

endmodule

(* synthesize *)
module mkAuroraWrapper_X1Y27#(Clock gtx_clk_in, Clock init_clk, Reset init_rst_n, Clock qpllclk, Clock qpllrefclk) (Aurora_V7);
	Aurora_V7 auroraImport <- mkAuroraImport_X1Y27(gtx_clk_in, init_clk, init_rst_n, qpllclk, qpllrefclk);

	interface Aurora_Pins_VC707 aurora = auroraImport.aurora;
	interface AuroraControllerIfc user = auroraImport.user;
	interface Clock aurora_clk = auroraImport.aurora_clk;
	interface Reset aurora_rst = auroraImport.aurora_rst;
endmodule

endpackage: AuroraImportVC707_X1Y27
