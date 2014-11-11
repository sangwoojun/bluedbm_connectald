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
//import FlashController::*;
import FlashCtrlArtixModel::*;
import NullResetN::*;

interface ArtixTopIfc; 
	//(* prefix = "" *)
	//interface FlashCtrlPins pins;
	interface Aurora_Pins#(4) pins_aurora;
endinterface


(* no_default_clock, no_default_reset *)
(*synthesize*)
module mkTopArtixModel#(
		Clock sysClkP, 
		Clock sysClkN,
		Clock gtp_clk_0_p,
		Clock gtp_clk_0_n
		//Reset sysRstn
	) (ArtixTopIfc);


	//Null reset that's always high
	NullResetNIfc nullResetN <- mkNullResetN();

	//Flash controller
	FlashControllerIfc flashCtrl <- mkFlashCtrlArtixModel(sysClkP, sysClkN, nullResetN.rst_n/*sysRstn*/);
	Clock clk0 = flashCtrl.infra.sysclk0;
	Reset rst0 = flashCtrl.infra.sysrst0;

	//Aurora
	Clock gtp_clk_0 <- mkClockIBUFDS_GTE2(True, gtp_clk_0_p, gtp_clk_0_n, clocked_by clk0, reset_by rst0);
	AuroraIfc auroraIfc <- mkAuroraIntra(gtp_clk_0, clocked_by clk0, reset_by rst0);

	//Debug register
	Reg#(Tuple2#(DataIfc, PacketType)) debugRecPacket <- mkRegU(clocked_by clk0, reset_by rst0);
	Reg#(Bit#(64)) debugFwdCnt <- mkReg(0, clocked_by clk0, reset_by rst0);
	
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
		debugFwdCnt <= debugFwdCnt + 1;
	endrule


	//Debug
	CSDebugIfc csDebug <- mkChipscopeDebug(clocked_by clk0, reset_by rst0);
	Vector#(NUM_DEBUG_ILAS, DebugILA) csDebugIla = newVector(); //8
	csDebugIla[0] = csDebug.ila0;
	csDebugIla[1] = csDebug.ila1;
	csDebugIla[2] = csDebug.ila2;
	csDebugIla[3] = csDebug.ila3;
	csDebugIla[4] = csDebug.ila4;
	csDebugIla[5] = csDebug.ila5;
	csDebugIla[6] = csDebug.ila6;
	csDebugIla[7] = csDebug.ila7;
	for (Integer i=0; i < valueOf(NUM_DEBUG_ILAS); i=i+1) begin
		rule setILAZero;
			csDebugIla[i].setDebug0(0);
			csDebugIla[i].setDebug1(0);
			csDebugIla[i].setDebug2(0);
			csDebugIla[i].setDebug3(0);
			csDebugIla[i].setDebug4(0);
			csDebugIla[i].setDebug5_64(0);
			//csDebugIla[i].setDebug6_64(0);
		endrule
	end

	rule setDebug;
		let debugCnts = auroraIfc.getDebugCnts();
		let gearboxSendCnt = tpl_1(debugCnts);
		let gearboxRecCnt = tpl_2(debugCnts);
		let auroraSendCntCC = tpl_3(debugCnts);
		let auroraRecCntCC = tpl_4(debugCnts);
		csDebugIla[0].setDebug6_64(zeroExtend(gearboxSendCnt));
		csDebugIla[1].setDebug6_64(zeroExtend(gearboxRecCnt));
		csDebugIla[2].setDebug6_64(zeroExtend(auroraSendCntCC));
		csDebugIla[3].setDebug6_64(zeroExtend(auroraRecCntCC));
		csDebugIla[4].setDebug6_64(0);
		csDebugIla[5].setDebug6_64(0);
		csDebugIla[6].setDebug6_64(0);
		csDebugIla[7].setDebug6_64(0);
		csDebug.vio.setDebugVin(zeroExtend(debugFwdCnt));
	endrule


	/*
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
		*/
	interface AuroraPins pins_aurora = auroraIfc.aurora;

endmodule
	







