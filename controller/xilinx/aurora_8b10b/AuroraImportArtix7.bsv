package AuroraImportArtix7;

import Clocks :: *;
import DefaultValue :: *;
import Xilinx :: *;
import XilinxCells :: *;

import FIFO::*;

typedef 8 HeaderSz;
typedef TSub#(128,8) BodySz;
typedef TMul#(2,TSub#(128,HeaderSz)) DataIfcSz;
typedef Bit#(DataIfcSz) DataIfc;
typedef Bit#(6) PacketType;

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

	Clock aclk = auroraIntraImport.aurora_clk;
	Reset arst = auroraIntraImport.aurora_rst;

	SyncFIFOIfc#(Tuple2#(DataIfc,PacketType)) sendQ <- mkSyncFIFOFromCC(8, auroraIntraImport.aurora_clk);
	SyncFIFOIfc#(Tuple2#(DataIfc,PacketType)) recvQ <- mkSyncFIFOToCC(8, auroraIntraImport.aurora_clk, auroraIntraImport.aurora_rst);
	//FIFO#(DataIfc) sendQ <- mkSizedFIFO(32, clocked_by aclk, reset_by arst);
	//FIFO#(DataIfc) recvQ <- mkSizedFIFO(32, clocked_by aclk, reset_by arst);
	Reg#(Maybe#(Tuple2#(Bit#(BodySz), PacketType))) packetSendBuffer <- mkReg(tagged Invalid, clocked_by aclk, reset_by arst);
	rule sendPacketPart;
		if ( isValid(packetSendBuffer) ) begin
			let btpl = fromMaybe(?, packetSendBuffer);
			auroraIntraImport.user.send({2'b10,
				tpl_2(btpl), tpl_1(btpl)
				});
			packetSendBuffer <= tagged Invalid;
		end else begin
			sendQ.deq;
			let data = sendQ.first;
			packetSendBuffer <= tagged Valid 
				tuple2(
					truncate(tpl_1(data)>>valueOf(BodySz)),
					tpl_2(data)
				);
			auroraIntraImport.user.send({2'b00, tpl_2(data),truncate(tpl_1(data))});
		end
	endrule

	Reg#(Maybe#(Bit#(BodySz))) packetRecvBuffer <- mkReg(tagged Invalid, clocked_by aclk, reset_by arst);
	Reg#(Bit#(1)) curRecvOffset <- mkReg(0, clocked_by aclk, reset_by arst);
	rule recvPacketPart;
		let crdata <- auroraIntraImport.user.receive;
		//recvQ.enq(zeroExtend(crdata));
		Bit#(BodySz) cdata = truncate(crdata);
		Bit#(8) header = truncate(crdata>>valueOf(BodySz));
		Bit#(1) idx = header[7];
		PacketType ptype = truncate(header);

		if ( isValid(packetRecvBuffer) ) begin
			let pdata = fromMaybe(0, packetRecvBuffer);
			if ( idx == 1 ) begin
				packetRecvBuffer <= tagged Invalid;
				recvQ.enq( tuple2({cdata, pdata}, ptype) );
			end
			else begin
				packetRecvBuffer <= tagged Valid cdata;
			end
		end
		else begin
			if ( idx == 0 ) 
				packetRecvBuffer <= tagged Valid cdata;
		end
	endrule

/*
	rule mirror;
		sendQ.enq(recvQ.first);
		recvQ.deq;
	endrule
*/

	method Action send(DataIfc data, PacketType ptype);
		sendQ.enq(tuple2(data, ptype));
	endmethod
	method ActionValue#(Tuple2#(DataIfc, PacketType)) receive;
		recvQ.deq;
		return recvQ.first;
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

	schedule (user_receive) CF (user_send);
	schedule (user_send) C (user_send);
	schedule (user_receive) C (user_receive);

endmodule

endpackage: AuroraImportArtix7
