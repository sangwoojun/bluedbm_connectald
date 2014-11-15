import FIFOF::*;
import FIFO::*;
import BRAMFIFO::*;
import BRAM::*;
import GetPut::*;
import ClientServer::*;
import Vector::*;

import PortalMemory::*;
import MemTypes::*;
import MemreadEngine::*;
import MemwriteEngine::*;
import Pipe::*;

import AuroraGearbox::*;
import AuroraCommon::*;
import AuroraImportFmc1::*;
import ControllerTypes::*;

//defined in controllertypes.bsv
/*
interface FlashCtrlUser;
	method Action sendCmd (FlashCmd cmd);
	method Action writeWord (Bit#(128) data, TagT tag);
	method ActionValue#(Tuple2#(Bit#(128), TagT)) readWord ();
	method ActionValue#(TagT) writeDataReq();
	method ActionValue#(Tuple2#(TagT, StatusT)) ackStatus ();
endinterface
*/


interface FCVirtexDebug;
	method Tuple2#(DataIfc, PacketType) debugRecPacket();
	method Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bit#(32)) getDebugCnts;
endinterface

interface FlashCtrlVirtexIfc;
	interface FlashCtrlUser user;
	interface Aurora_Pins#(4) aurora;
	interface FCVirtexDebug debug;
endinterface


module mkFlashCtrlVirtex#(
	Clock gtx_clk_p, Clock gtx_clk_n, Clock clk250) (FlashCtrlVirtexIfc);

	//GTX-GTP Aurora
	AuroraIfc auroraIntra <- mkAuroraIntra(gtx_clk_p, gtx_clk_n, clk250);

	FIFO#(FlashCmd) flashCmdQ <- mkSizedFIFO(16); //should not have back pressure
	FIFO#(Tuple2#(Bit#(128), TagT)) wrDataQ <- mkSizedFIFO(16); //TODO size?
	FIFO#(Tuple2#(Bit#(128), TagT)) rdDataQ <- mkSizedFIFO(16); //TODO size?
	FIFO#(TagT) wrReqQ <- mkSizedFIFO(valueOf(NumTags)); //TODO size?
	FIFO#(Tuple2#(TagT, StatusT)) ackQ <- mkSizedFIFO(valueOf(NumTags)); //TODO size?

	Reg#(Tuple2#(DataIfc, PacketType)) debugRecPacketV <- mkRegU();
//typedef 8 HeaderSz;
//typedef TSub#(128,8) BodySz;
//typedef TMul#(2,TSub#(128,HeaderSz)) DataIfcSz;
//typedef Bit#(DataIfcSz) DataIfc; //240 bits
//typedef Bit#(6) PacketType;
//method Action send(DataIfc data, PacketType ptype);
//method ActionValue#(Tuple2#(DataIfc, PacketType)) receive;


	
	//SEND V7 -> A7 rules: sendCmd and write data
	//Prioritize sendCmd over writeData
	//TODO: must check if there's space on A7 to accept cmd, otherwise aurora
		//may prevent write data from being sent 
		// only umTags commands in flight at any time; just create buffer on Artix to
		// make sure command drains
	(* descending_urgency = "forwardCmd, forwardWrData" *)
	rule forwardCmd;
		DataIfc data = zeroExtend(pack(flashCmdQ.first));
		PacketClass dataClass = F_CMD;
		PacketType dataType = zeroExtend(pack(dataClass));
		auroraIntra.send(data, dataType);
		flashCmdQ.deq();
	endrule

	rule forwardWrData;
		//TODO pack data more densely into 240 bit bursts
		DataIfc data = zeroExtend(pack(wrDataQ.first));
		PacketClass dataClass = F_DATA;
		PacketType dataType = zeroExtend(pack(dataClass));
		auroraIntra.send(data, dataType);
		wrDataQ.deq();
	endrule
		

	//RECEIVE A7 -> V7 rules
	//TODO need to break up the rules because ActionValue receive

	FIFO#(Tuple2#(DataIfc, PacketType)) receiveQ <- mkFIFO();
	rule receivePacketBuf;
		let typedData <- auroraIntra.receive();
		receiveQ.enq(typedData);
	endrule

	rule receivePacket;
		let typedData = receiveQ.first;
		receiveQ.deq;
		//let typedData <- auroraIntra.receive();
		debugRecPacketV <= typedData;
		DataIfc data = tpl_1(typedData);
		PacketType dataType = tpl_2(typedData);
		PacketClass dataClass = unpack(truncate(dataType)); 
		if (dataClass == F_DATA) begin
			rdDataQ.enq(unpack(truncate(data))); //TODO need to repack bursts
		end
		else if (dataClass == F_WR_REQ) begin
			TagT tag = unpack(truncate(data));
			wrReqQ.enq(tag); 
		end
		else if (dataClass == F_ACK) begin 
			Tuple2#(TagT, StatusT) ack = unpack(truncate(data));
			ackQ.enq(ack);
		end
		else begin
			$display("**ERROR: Unknown Packet Type"); //TODO go into err state
		end
		// Possible scenerio: pcie can't drain rdata fast enough? acks or wr_req 
		// can't be received either. but host always has space before issuing
		// rdata, so it might be ok? it drains eventually. 
	endrule
	

	//bsim testing
	/*
	Reg#(Bit#(32)) dataReg <- mkReg(0);
	rule sendAurora;
		dataReg <= dataReg + 1;
		auroraIntra.send(zeroExtend(dataReg), 0);
		$display("aurora SEND data = %x", dataReg);
	endrule

	//receive slowly
	Integer recDelay = 1000;
	Reg#(Bit#(32)) delayReg <- mkReg(fromInteger(recDelay));
	rule receiveAurora;
		if (delayReg == 0) begin
			let typedData <- auroraIntra.receive();
			let data = tpl_1(typedData);
			$display("aurora RECEIVED data = %x", data);
			delayReg <= fromInteger(recDelay);
		end
		else begin
			delayReg <= delayReg - 1;
		end
	endrule
	*/	


			
	interface FlashCtrlUser user;
		method Action sendCmd (FlashCmd cmd); 
			flashCmdQ.enq(cmd);
		endmethod

		method Action writeWord (Tuple2#(Bit#(128), TagT) taggedData);
			wrDataQ.enq(taggedData);
		endmethod
			
		method ActionValue#(Tuple2#(Bit#(128), TagT)) readWord ();
			rdDataQ.deq();
			return rdDataQ.first();
		endmethod

		method ActionValue#(TagT) writeDataReq();
			wrReqQ.deq();
			return wrReqQ.first();
		endmethod

		method ActionValue#(Tuple2#(TagT, StatusT)) ackStatus ();
			ackQ.deq();
			return ackQ.first();
		endmethod
	endinterface

	interface FCVirtexDebug debug;
		method Tuple2#(DataIfc, PacketType) debugRecPacket();
			return debugRecPacketV;
		endmethod
		method Tuple4#(Bit#(32), Bit#(32), Bit#(32), Bit#(32)) getDebugCnts = auroraIntra.getDebugCnts;
	endinterface

	interface Aurora_Pins aurora = auroraIntra.aurora;

endmodule





