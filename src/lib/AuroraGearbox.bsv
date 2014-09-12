import FIFO::*;
import FIFOF::*;
import Clocks :: *;

typedef 8 HeaderSz;
typedef TSub#(128,8) BodySz;
typedef TMul#(2,TSub#(128,HeaderSz)) DataIfcSz;
typedef Bit#(DataIfcSz) DataIfc;
typedef Bit#(6) PacketType;
typedef 128 AuroraWidth;


interface AuroraGearboxIfc;
	method Action send(DataIfc data, PacketType ptype);
	method ActionValue#(Tuple2#(DataIfc, PacketType)) recv;

	method Action auroraRecv(Bit#(AuroraWidth) word);
	method ActionValue#(Bit#(AuroraWidth)) auroraSend;
endinterface

module mkAuroraGearbox#(Clock aclk, Reset arst) (AuroraGearboxIfc);
	SyncFIFOIfc#(Tuple2#(DataIfc,PacketType)) sendQ <- mkSyncFIFOFromCC(4, aclk);

	Integer recvQDepth = 32;
	Integer windowSize = 16;
	SyncFIFOIfc#(Tuple2#(DataIfc,PacketType)) recvQ <- mkSyncFIFOToCC(4, aclk, arst);
	FIFO#(Tuple2#(DataIfc,PacketType)) recvBufferQ <- mkSizedFIFO(recvQDepth, clocked_by aclk, reset_by arst);
	Reg#(Bit#(16)) maxInFlight <- mkReg(0, clocked_by aclk, reset_by arst);
	Reg#(Bit#(16)) curInQ <- mkReg(0, clocked_by aclk, reset_by arst);
	FIFOF#(Bit#(8)) flowControlQ <- mkFIFOF(clocked_by aclk, reset_by arst);
	rule emitFlowControlPacket
		(maxInFlight+curInQ+fromInteger(windowSize) < fromInteger(recvQDepth));

		flowControlQ.enq(fromInteger(windowSize));
		maxInFlight <= maxInFlight + fromInteger(windowSize);
	endrule

	Reg#(Bit#(16)) curSendBudget <- mkReg(0, clocked_by aclk, reset_by arst);

	FIFO#(Bit#(AuroraWidth)) auroraOutQ <- mkFIFO(clocked_by aclk, reset_by arst);
	Reg#(Maybe#(Tuple2#(Bit#(BodySz), PacketType))) packetSendBuffer <- mkReg(tagged Invalid, clocked_by aclk, reset_by arst);
	rule sendPacketPart;
		if ( flowControlQ.notEmpty ) begin
			flowControlQ.deq;
			PacketType ptype = 0;
			auroraOutQ.enq({2'b01, ptype, zeroExtend(flowControlQ.first)});
		end else
		if ( curSendBudget > 0 ) begin
			if ( isValid(packetSendBuffer) ) begin
				let btpl = fromMaybe(?, packetSendBuffer);
				//auroraIntraImport.user.send({2'b10,
				auroraOutQ.enq({2'b10,
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
				auroraOutQ.enq({2'b00, tpl_2(data),truncate(tpl_1(data))});
			end
		end
	endrule

	FIFO#(Bit#(AuroraWidth)) auroraInQ <- mkFIFO(clocked_by aclk, reset_by arst);
	Reg#(Maybe#(Bit#(BodySz))) packetRecvBuffer <- mkReg(tagged Invalid, clocked_by aclk, reset_by arst);
	Reg#(Bit#(1)) curRecvOffset <- mkReg(0, clocked_by aclk, reset_by arst);
	rule recvPacketPart;
		let crdata = auroraInQ.first;
		auroraInQ.deq;
		Bit#(BodySz) cdata = truncate(crdata);
		Bit#(8) header = truncate(crdata>>valueOf(BodySz));
		Bit#(1) idx = header[7];
		Bit#(1) control = header[6];
		PacketType ptype = truncate(header);

		if ( control == 1 ) begin
			curSendBudget <= curSendBudget + truncate(cdata);
		end else
		if ( isValid(packetRecvBuffer) ) begin
			let pdata = fromMaybe(0, packetRecvBuffer);
			if ( idx == 1 ) begin
				packetRecvBuffer <= tagged Invalid;
				recvBufferQ.enq( tuple2({cdata, pdata}, ptype) );

				maxInFlight <= maxInFlight - 1;
				curInQ <= curInQ + 1;
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
	rule flushReadBuffer;
		curInQ <= curInQ - 1;

		recvBufferQ.deq;
		recvQ.enq(recvBufferQ.first);
	endrule

	method Action send(DataIfc data, PacketType ptype);
		sendQ.enq(tuple2(data, ptype));
	endmethod
	method ActionValue#(Tuple2#(DataIfc, PacketType)) recv;

		recvQ.deq;
		return recvQ.first;
	endmethod

	method Action auroraRecv(Bit#(AuroraWidth) word);
		auroraInQ.enq(word);
	endmethod
	method ActionValue#(Bit#(AuroraWidth)) auroraSend;
		auroraOutQ.deq;
		return auroraOutQ.first;
	endmethod
endmodule
