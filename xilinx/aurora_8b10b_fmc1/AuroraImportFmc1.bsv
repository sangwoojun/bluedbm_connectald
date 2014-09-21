package AuroraImportFmc1;

import FIFO::*;

import Clocks :: *;
import DefaultValue :: *;
import Xilinx :: *;
import XilinxCells :: *;
import XbsvXilinxCells::*;

import AuroraGearbox::*;


(* always_enabled, always_ready *)
interface Aurora_Pins#(numeric type lanes);
	(* prefix = "", result = "RXN" *)
	method Action rxn_in(Bit#(lanes) rxn_i);
	(* prefix = "", result = "RXP" *)
	method Action rxp_in(Bit#(lanes) rxp_i);

	(* prefix = "", result = "TXN" *)
	method Bit#(lanes) txn_out();
	(* prefix = "", result = "TXP" *)
	method Bit#(lanes) txp_out();
endinterface
(* always_enabled, always_ready *)
interface Aurora_Clock_Pins;
	//(* prefix = "", result = "" *)
	method Action gtx_clk_p(Bit#(1) v);
	//(* prefix = "", result = "" *)
	method Action gtx_clk_n(Bit#(1) v);
	
	interface Clock gtx_clk_p_deleteme_unused_clock;
	interface Clock gtx_clk_n_deleteme_unused_clock;
endinterface

interface AuroraImportIfc#(numeric type lanes);
	interface Clock aurora_clk;
	interface Reset aurora_rst;
	(* prefix = "" *)
	interface Aurora_Pins#(lanes) aurora;
	(* prefix = "" *)
	interface AuroraControllerIfc#(TMul#(lanes,32)) user;
endinterface

interface AuroraControllerIfc#(numeric type width);
	interface Reset aurora_rst_n;
		
	method Bit#(1) channel_up;
	method Bit#(1) lane_up;
	method Bit#(1) hard_err;
	method Bit#(1) soft_err;
	method Bit#(8) data_err_count;

	method Action send(Bit#(width) tx);
	method ActionValue#(Bit#(width)) receive();
endinterface


interface AuroraIfc;
	method Action send(DataIfc data, PacketType ptype);
	method ActionValue#(Tuple2#(DataIfc, PacketType)) receive;

	interface Clock clk;
	interface Reset rst;

	method Bit#(1) channel_up;
	method Bit#(1) lane_up;
	method Bit#(1) hard_err;
	method Bit#(1) soft_err;
	method Bit#(8) data_err_count;
	
	(* prefix = "" *)
	interface Aurora_Pins#(4) aurora;
endinterface

interface GtxClockImportIfc;
	interface Aurora_Clock_Pins aurora_clk;
	interface Clock gtx_clk_p_ifc;
	interface Clock gtx_clk_n_ifc;
	

endinterface

(* synthesize *)
module mkGtxClockImport (GtxClockImportIfc);
`ifndef BSIM
	B2C i_gtx_clk_p <- mkB2C();
	B2C i_gtx_clk_n <- mkB2C();

	interface Aurora_Clock_Pins aurora_clk;
	method Action gtx_clk_p(Bit#(1) v);
		i_gtx_clk_p.inputclock(v);
	endmethod
	method Action gtx_clk_n(Bit#(1) v);
		i_gtx_clk_n.inputclock(v);
	endmethod
	interface Clock gtx_clk_p_deleteme_unused_clock = i_gtx_clk_p.c; // These clocks are deleted from the netlist by the synth.tcl script
	interface Clock gtx_clk_n_deleteme_unused_clock = i_gtx_clk_n.c;
	endinterface
	//interface Clock gtx_clk = gtx_clk_i;
	interface Clock gtx_clk_p_ifc = i_gtx_clk_p.c;
	interface Clock gtx_clk_n_ifc = i_gtx_clk_n.c;
`else
	Clock clk <- exposeCurrentClock;
	
	interface Aurora_Clock_Pins aurora_clk;
	interface Clock gtx_clk_p_deleteme_unused_clock = clk; // These clocks are deleted from the netlist by the synth.tcl script
	interface Clock gtx_clk_n_deleteme_unused_clock = clk;
	endinterface
	//interface Clock gtx_clk = gtx_clk_i;
	interface Clock gtx_clk_p_ifc = clk;
	interface Clock gtx_clk_n_ifc = clk;
`endif
endmodule


(* synthesize *)
module mkAuroraIntra#(Clock gtx_clk_p, Clock gtx_clk_n, Clock clk250) (AuroraIfc);

	Clock cur_clk <- exposeCurrentClock; // assuming 200MHz clock
	Reset cur_rst <- exposeCurrentReset;
	

`ifndef BSIM
	ClockDividerIfc auroraIntraClockDiv4 <- mkDCMClockDivider(5, 4, clocked_by clk250);
	//ClockDividerIfc auroraIntraClockDiv4 <- mkDCMClockDivider(4, 5);
	Reset defaultReset <- exposeCurrentReset;
	Clock clk50 = auroraIntraClockDiv4.slowClock;
	//MakeResetIfc rst50ifc <- mkReset(8, True, clk50);
	MakeResetIfc rst50ifc2 <- mkReset(8, True, clk50);
	//Reset rst50 = rst50ifc.new_rst;
	Reset rst50 <- mkAsyncReset(2, defaultReset, clk50);
	Reset rst50_2 = rst50ifc2.new_rst;
	Reset rst50_2a <- mkAsyncReset(2, rst50_2, clk50);
	Clock fmc1_gtx_clk_i <- mkClockIBUFDS_GTE2(True, gtx_clk_p, gtx_clk_n);
	AuroraImportIfc#(4) auroraIntraImport <- mkAuroraImport_8b10b_fmc1(fmc1_gtx_clk_i, clk50, rst50, rst50);//rst50_2a);
`else
	//Clock gtx_clk = cur_clk;
	AuroraImportIfc#(4) auroraIntraImport <- mkAuroraImport_8b10b_bsim;
`endif


	Clock aclk = auroraIntraImport.aurora_clk;
	Reset arst = auroraIntraImport.aurora_rst;

	AuroraGearboxIfc auroraGearbox <- mkAuroraGearbox(aclk, arst);
	rule auroraOut;
		let d <- auroraGearbox.auroraSend;
		auroraIntraImport.user.send(d);
	endrule
	rule auroraIn;
		let d <- auroraIntraImport.user.receive;
		auroraGearbox.auroraRecv(d);
	endrule
		



	method Action send(DataIfc data, PacketType ptype);
		auroraGearbox.send(data, ptype);
	endmethod
	method ActionValue#(Tuple2#(DataIfc, PacketType)) receive;
		let d <- auroraGearbox.recv;
		return d;
	endmethod

	method channel_up = auroraIntraImport.user.channel_up;
	method lane_up = auroraIntraImport.user.lane_up;
	method hard_err = auroraIntraImport.user.hard_err;
	method soft_err = auroraIntraImport.user.soft_err;
	method data_err_count = auroraIntraImport.user.data_err_count;

	interface Clock clk = auroraIntraImport.aurora_clk;
	interface Reset rst = auroraIntraImport.aurora_rst;

	interface Aurora_Pins aurora = auroraIntraImport.aurora;
endmodule

module mkAuroraImport_8b10b_bsim (AuroraImportIfc#(4));
	Clock clk <- exposeCurrentClock;
	Reset rst <- exposeCurrentReset;

	FIFO#(Bit#(128)) mirrorQ <- mkFIFO;

	interface aurora_clk = clk;
	interface aurora_rst = rst;
	interface AuroraControllerIfc user;
		interface Reset aurora_rst_n = rst;

		method Bit#(1) channel_up;
			return 0;
		endmethod
		method Bit#(1) lane_up;
			return 0;
		endmethod
		method Bit#(1) hard_err;
			return 0;
		endmethod
		method Bit#(1) soft_err;
			return 0;
		endmethod
		method Bit#(8) data_err_count;
			return 0;
		endmethod

		method Action send(Bit#(128) data);
			mirrorQ.enq(data);
		endmethod
		method ActionValue#(Bit#(128)) receive;
			mirrorQ.deq;
			return mirrorQ.first;
		endmethod
	endinterface
endmodule

import "BVI" aurora_8b10b_fmc1_exdes =
module mkAuroraImport_8b10b_fmc1#(Clock gtx_clk_in, Clock init_clk, Reset init_rst_n, Reset gt_rst_n) (AuroraImportIfc#(4));
	default_clock no_clock;
	default_reset no_reset;

	input_clock (INIT_CLK_IN) = init_clk;
	input_reset (RESET_N) = init_rst_n;
	input_reset (GT_RESET_N) = gt_rst_n;

	output_clock aurora_clk(USER_CLK);
	output_reset aurora_rst(USER_RST_N) clocked_by (aurora_clk);

	input_clock (GTX_CLK) = gtx_clk_in;

	interface Aurora_Pins aurora;
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
		method ERR_COUNT data_err_count;

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

endpackage: AuroraImportFmc1
