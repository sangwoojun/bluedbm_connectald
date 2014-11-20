package AuroraImportArtix7;

import FIFO::*;
import FIFOF::*;
import Clocks :: *;
import DefaultValue :: *;
import Xilinx :: *;
import XilinxCells :: *;

import AuroraGearbox::*;

typedef 8 HeaderSz;
typedef TSub#(128,8) BodySz;
typedef TMul#(2,TSub#(128,HeaderSz)) DataIfcSz;
typedef Bit#(DataIfcSz) DataIfc;
typedef Bit#(6) PacketType;

interface AuroraIfc;
	method Action send(DataIfc data, PacketType ptype);
	method ActionValue#(Tuple2#(DataIfc, PacketType)) receive;
	method Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bit#(32)) getDebugCnts;


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

/*
module mkAurora#(AuroraImportIfc#(lanes) aurora) (AuroraIfc#(width))
	provisos (Mul#(lanes, 32, width));

	method send = aurora.user.send;
	method receive = aurora.user.receive;

	method channel_up = aurora.user.channel_up;
	method lane_up = aurora.user.lane_up;
	method hard_err = aurora.user.hard_err;
	method soft_err = aurora.user.soft_err;
	method data_err_count = aurora.user.data_err_count;

	interface Clock clk = aurora.aurora_clk;
	interface Reset rst = aurora.aurora_rst;

endmodule
*/
(* synthesize *)
module mkAuroraIntra#(Clock gtp_clk) (AuroraIfc);
	//provisos (Div#(width, 32, lanes), Mul#(32, lanes, width));
	Clock cur_clk <- exposeCurrentClock; // assuming 100MHz clock
	Reset cur_rst <- exposeCurrentReset;
	
`ifndef BSIM
	ClockDividerIfc auroraIntraClockDiv2 <- mkDCMClockDivider(2, 10);
	Clock clk50 = auroraIntraClockDiv2.slowClock;
	MakeResetIfc rst50ifc <- mkReset(8, True, clk50);
	MakeResetIfc rst50ifc2 <- mkReset(8, True, clk50);
	Reset rst50 = rst50ifc.new_rst;
	Reset rst50_2 = rst50ifc2.new_rst;

	AuroraImportIfc#(4) auroraIntraImport <- mkAuroraImport_8b10b(gtp_clk, clk50, rst50, rst50_2);


	Reg#(Bit#(32)) auroraGtResetCounter <- mkReg(0);
	rule resetAurora;
		if ( auroraIntraImport.user.channel_up == 0 && auroraIntraImport.user.lane_up == 0 )
		begin
			if ( auroraGtResetCounter >= 100000000 + 50000000 ) begin // 2 seconds
				rst50ifc2.assertReset;
				auroraGtResetCounter <= 0;
			end
			else if ( auroraGtResetCounter >= 100000000 ) begin // 2 seconds
				rst50ifc2.assertReset;
				auroraGtResetCounter <= auroraGtResetCounter + 1;
			end else begin
				auroraGtResetCounter <= auroraGtResetCounter + 1;
			end
		end
	endrule

`else
	AuroraImportIfc#(4) auroraIntraImport <- mkAuroraImport_8b10b_bsim;
`endif


	Clock aclk = auroraIntraImport.aurora_clk;
	Reset arst = auroraIntraImport.aurora_rst;

	Reg#(Bit#(32)) gearboxSendCnt <- mkReg(0);
	Reg#(Bit#(32)) gearboxRecCnt <- mkReg(0);
	Reg#(Bit#(32)) auroraSendCnt <- mkReg(0, clocked_by aclk, reset_by arst);
	Reg#(Bit#(32)) auroraRecCnt <- mkReg(0, clocked_by aclk, reset_by arst);
	Reg#(Bit#(32)) auroraSendCntCC <- mkSyncRegToCC(0, aclk, arst);
	Reg#(Bit#(32)) auroraRecCntCC <- mkSyncRegToCC(0, aclk, arst);
	rule syncCnt;
		auroraSendCntCC <= auroraSendCnt;
		auroraRecCntCC <= auroraRecCnt;
	endrule


	AuroraGearboxIfc auroraGearbox <- mkAuroraGearbox(aclk, arst);
	rule auroraOut if (auroraIntraImport.user.channel_up == 1);
		let d <- auroraGearbox.auroraSend;
		//if ( auroraIntraImport.user.channel_up == 1 ) begin
			auroraSendCnt <= auroraSendCnt + 1;
			auroraIntraImport.user.send(d);
		//end
	endrule
	/*
	rule resetDeadLink ( auroraIntraImport.user.channel_up == 0);
		auroraGearbox.resetLink;
	endrule
	*/
	rule auroraIn;
		let d <- auroraIntraImport.user.receive;
		auroraRecCnt <= auroraRecCnt + 1;
		auroraGearbox.auroraRecv(d);
	endrule

/*
	rule mirror;
		sendQ.enq(recvQ.first);
		recvQ.deq;
	endrule
*/

	method Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bit#(32)) getDebugCnts;
		return tuple4(gearboxSendCnt, gearboxRecCnt, auroraSendCntCC, auroraRecCntCC);
	endmethod

	method Action send(DataIfc data, PacketType ptype);
		auroraGearbox.send(data, ptype);
		gearboxSendCnt <= gearboxSendCnt + 1;
	endmethod
	method ActionValue#(Tuple2#(DataIfc, PacketType)) receive;
		let d <- auroraGearbox.recv;
		gearboxRecCnt <= gearboxRecCnt + 1;
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

	FIFOF#(Bit#(128)) mirrorQ <- mkSizedFIFOF(2);
	Reg#(Bit#(1)) laneUpR <- mkReg(0);
	Reg#(Bit#(32)) laneUpDelay <- mkReg(500);

	rule updateLaneUp;
		if (laneUpDelay ==0) begin
			laneUpR <= 1;
		end
		else begin
			laneUpDelay <= laneUpDelay - 1;
		end
	endrule


	rule detectFull if (!mirrorQ.notFull);
		$display("WARNING: mirrorQ is full!");
	endrule

	interface aurora_clk = clk;
	interface aurora_rst = rst;
	interface AuroraControllerIfc user;
		interface Reset aurora_rst_n = rst;

		method Bit#(1) channel_up;
			return laneUpR; 
		endmethod
		method Bit#(1) lane_up;
			return laneUpR;
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










(* always_enabled, always_ready *)
interface Aurora_Pins#(numeric type lanes);
	`ifndef BSIM
	(* prefix = "", result = "RXN" *)
	method Action rxn_in(Bit#(lanes) rxn_i);
	(* prefix = "", result = "RXP" *)
	method Action rxp_in(Bit#(lanes) rxp_i);

	(* prefix = "", result = "TXN" *)
	method Bit#(lanes) txn_out();
	(* prefix = "", result = "TXP" *)
	method Bit#(lanes) txp_out();
	`endif
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

interface AuroraImportIfc#(numeric type lanes);
	interface Clock aurora_clk;
	interface Reset aurora_rst;
	(* prefix = "" *)
	interface Aurora_Pins#(lanes) aurora;
	(* prefix = "" *)
	interface AuroraControllerIfc#(TMul#(32,lanes)) user;
endinterface

`ifndef BSIM

import "BVI" aurora_8b10b_exdes =
module mkAuroraImport_8b10b#(Clock gtx_clk_in, Clock init_clk, Reset init_rst_n, Reset gt_rst_n) (AuroraImportIfc#(4));

	default_clock no_clock;
	default_reset no_reset;

	input_clock (INIT_CLK_IN) = init_clk;

	input_reset (RESET_N) = init_rst_n;
	input_reset (GT_RESET_N) = gt_rst_n;

	output_clock aurora_clk(USER_CLK);
	output_reset aurora_rst(USER_RST_N) clocked_by (aurora_clk);
		
	input_clock (GTP_CLK) = gtx_clk_in;

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

`endif //BSIM

endpackage: AuroraImportArtix7
