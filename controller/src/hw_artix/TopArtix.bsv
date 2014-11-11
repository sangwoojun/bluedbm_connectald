import FIFOF		::*;
import FIFO		::*;
import Vector		::*;
import Connectable ::*;
import RegFile::*;
import Clocks :: *;
import DefaultValue :: *;
import Xilinx :: *;
import XilinxCells :: *;

import ChipscopeWrapper::*;
import AuroraGearbox::*;
import AuroraImportArtix7 :: *;
import ControllerTypes::*;
import FlashController::*;
import NullResetN::*;

interface ArtixTopIfc; 
	(* prefix = "" *)
	interface FlashCtrlPins pins;
	interface Aurora_Pins#(4) pins_aurora;
endinterface


(* no_default_clock, no_default_reset *)
(*synthesize*)
module mkTopArtix#(
		Clock sysClkP, 
		Clock sysClkN,
		Clock gtp_clk_0_p,
		Clock gtp_clk_0_n
		//Reset sysRstn
	) (ArtixTopIfc);


	//Null reset that's always high
	NullResetNIfc nullResetN <- mkNullResetN();

	//Flash controller
	FlashControllerIfc flashCtrl <- mkFlashController(sysClkP, sysClkN, nullResetN.rst_n/*sysRstn*/);
	Clock clk0 = flashCtrl.infra.sysclk0;
	Reset rst0 = flashCtrl.infra.sysrst0;

	//Aurora
	Clock gtp_clk_0 <- mkClockIBUFDS_GTE2(True, gtp_clk_0_p, gtp_clk_0_n, clocked_by clk0, reset_by rst0);
	AuroraIfc auroraIfc <- mkAuroraIntra(gtp_clk_0, clocked_by clk0, reset_by rst0);

	//Debug register
	Reg#(Tuple2#(DataIfc, PacketType)) debugRecPacket <- mkRegU(clocked_by clk0, reset_by rst0);
	
	//TODO package and unpackage data for better efficiency

	//RECEIVE V7 -> A7
	rule receivePacket;
		let typedData <- auroraIfc.receive();
		debugRecPacket <= typedData;
		DataIfc data = tpl_1(typedData);
		PacketType dataType = tpl_2(typedData);
		PacketClass dataClass = unpack(truncate(dataType));
		if (dataClass == F_CMD) begin
			FlashCmd cmd = unpack(truncate(data));
			flashCtrl.user.sendCmd(cmd);
		end
		else if (dataClass == F_DATA) begin //wdata to flash
			Tuple2#(Bit#(128), TagT) taggedData = unpack(truncate(data));
			flashCtrl.user.writeWord(taggedData);
		end
		else begin
			$display("**ERROR: Unknown packet type received");
		end
	endrule

	//SEND A7 -> V7
	(* descending_urgency = "forwardAck, forwardWrReq, forwardRdData" *)
	rule forwardAck;
		Tuple2#(TagT, StatusT) ack <- flashCtrl.user.ackStatus();
		DataIfc data = zeroExtend(pack(ack));
		PacketClass dataClass = F_ACK;
		PacketType dataType = zeroExtend(pack(dataClass));
		auroraIfc.send(data, dataType);
	endrule

	rule forwardWrReq;
		TagT wrDataReq <- flashCtrl.user.writeDataReq();
		DataIfc data = zeroExtend(pack(wrDataReq));
		PacketClass dataClass = F_WR_REQ;
		PacketType dataType = zeroExtend(pack(dataClass));
		auroraIfc.send(data, dataType);
	endrule

	rule forwardRdData;
		Tuple2#(Bit#(128), TagT) rd <- flashCtrl.user.readWord();
		DataIfc data = zeroExtend(pack(rd));
		PacketClass dataClass = F_DATA;
		PacketType dataType = zeroExtend(pack(dataClass));
		auroraIfc.send(data, dataType);
	endrule


	//Debug
	Vector#(NUM_BUSES, Reg#(Bit#(64))) debugSplit <- replicateM(mkReg(0, clocked_by clk0, reset_by rst0));
	rule splitDebug;
		DataIfc data = tpl_1(debugRecPacket);
		debugSplit[0] <= data[63:0];
		debugSplit[1] <= data[127:64];
		debugSplit[2] <= data[191:128];
		debugSplit[3] <= zeroExtend(data[239:192]);
	endrule

	for (Integer i=0; i < valueOf(NUM_BUSES); i=i+1) begin
		rule debugSet;
			flashCtrl.debug.debugBus[i].debugPort4(zeroExtend(pack(tpl_2(debugRecPacket)))); //packet type
			flashCtrl.debug.debugBus[i].debugPort5_64(debugSplit[i]);
			flashCtrl.debug.debugBus[i].debugPort6_64(0);
		endrule
	end

	rule debugSetVio;
		flashCtrl.debug.debugVio.setDebugVin(0);
	endrule


	interface FlashCtrlPins pins = flashCtrl.pins;
	interface AuroraPins pins_aurora = auroraIfc.aurora;

endmodule
	







