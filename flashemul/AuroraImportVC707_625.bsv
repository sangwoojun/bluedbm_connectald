
package AuroraImportVC707_625;

import Clocks :: *;
import AuroraImportVC707::*;

/*
typedef 2 AuroraPorts;

interface AuroraIfc;
	method Action send(Bit#(64) data);
	method ActionValue#(Bit#(64)) receive;

	interface Clock clk;
	interface Reset rst;

	method Bit#(1) channel_up;
	method Bit#(1) lane_up;
	method Bit#(1) hard_err;
	method Bit#(1) soft_err;
	method Bit#(8) data_err_count;
	
	interface MakeResetIfc auroraRst;
endinterface

module mkAurora#(Aurora_V7 aurora, MakeResetIfc auroraRst) (AuroraIfc);
	method send = aurora.user.send;
	method receive = aurora.user.receive;

	method channel_up = aurora.user.channel_up;
	method lane_up = aurora.user.lane_up;
	method hard_err = aurora.user.hard_err;
	method soft_err = aurora.user.soft_err;
	method data_err_count = aurora.user.data_err_count;

	interface Clock clk = aurora.aurora_clk;
	interface Reset rst = aurora.aurora_rst;
	interface MakeResetIfc auroraRst = auroraRst;
endmodule


(* always_enabled, always_ready *)
interface Aurora_Pins_VC707_625;
	(* prefix = "", result = "RXN" *)
	method Action rxn_in(Bit#(1) rxn_i);
	(* prefix = "", result = "RXP" *)
	method Action rxp_in(Bit#(1) rxp_i);

	(* prefix = "", result = "TXN" *)
	method Bit#(1) txn_out();
	(* prefix = "", result = "TXP" *)
	method Bit#(1) txp_out();

endinterface
interface AuroraControllerIfc;
	interface Reset aurora_rst_n;
		
	method Bit#(1) channel_up;
	method Bit#(1) lane_up;
	method Bit#(1) hard_err;
	method Bit#(1) soft_err;
	method Bit#(8) data_err_count;

	method Action send(Bit#(64) tx);
	method ActionValue#(Bit#(64)) receive();
endinterface

interface Aurora_V7;
	interface Clock aurora_clk;
	interface Reset aurora_rst;
	(* prefix = "" *)
	interface Aurora_Pins_VC707_625 aurora;
	(* prefix = "" *)
	interface AuroraControllerIfc user;
endinterface
*/

import "BVI" aurora_64b66b_625_exdes =
//module mkAuroraImport#(Clock gtx_clk_p, Clock gtx_clk_n, Clock init_clk, Reset init_rst_n) (Aurora_V7);
module mkAuroraImport625#(Clock gtx_clk_in, Clock init_clk, Reset init_rst_n) (Aurora_V7);
	input_clock (INIT_CLK_IN) = init_clk;
	input_reset (RESET_N) = init_rst_n;
	
	//input_reset (PMA_INIT_N) = init_rst_n;

	//input_clock (GTXQ0_CLK) = gtx_clk; //IBUFDS_GTE2 IBUFDS_GTXE2_CLK1
		
	output_clock aurora_clk(USER_CLK);
	output_reset aurora_rst(USER_RST_N) clocked_by (aurora_clk);

	default_clock no_clock;
	default_reset no_reset;
		
		//input_clock (GTXQ0_P) = gtx_clk_p;
		//input_clock (GTXQ0_N) = gtx_clk_n;
		input_clock (GTXQ_CLK) = gtx_clk_in;
	

	interface Aurora_Pins_VC707 aurora;
		//method    RXN rxn_in clocked_by(no_clock) reset_by (no_reset);
		method rxn_in(RXN) enable((*inhigh*) rx_n_en) reset_by(no_reset) clocked_by(gtx_clk_in);
		method rxp_in(RXP) enable((*inhigh*) rx_p_en) reset_by(no_reset) clocked_by(gtx_clk_in);
		method TXN txn_out() reset_by(no_reset) clocked_by(gtx_clk_in); //FIXME used to be rawClock (init_clk). Would this work better?
		method TXP txp_out() reset_by(no_reset) clocked_by(gtx_clk_in);

	endinterface

	interface AuroraControllerIfc user;
		//output_clock aurora_clk(USER_CLK);
		output_reset aurora_rst_n(USER_RST) clocked_by (aurora_clk);
		//output_reset aurora_rst(USER_RST_N) clocked_by (aurora_clk);
		
		//aurora_clk = aurora_clk;
		//aurora_rst = aurora_rst;

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

///////////////////////////////////////
/*
interface AuroraWrapperIfc;
	(* prefix = "" *)
	interface Aurora_Pins_VC707_625 aurora;
	interface AuroraIfc user;
endinterface
*/

(* synthesize *)
module mkAuroraWrapper625#(Clock gtx_clk_in, Clock init_clk, Reset init_rst_n) (Aurora_V7);
	Aurora_V7 auroraImport <- mkAuroraImport625(gtx_clk_in, init_clk, init_rst_n);

	interface Aurora_Pins_VC707_625 aurora = auroraImport.aurora;
	interface AuroraControllerIfc user = auroraImport.user;
	interface Clock aurora_clk = auroraImport.aurora_clk;
	interface Reset aurora_rst = auroraImport.aurora_rst;
endmodule
///////////////////////////////////////

endpackage: AuroraImportVC707_625
