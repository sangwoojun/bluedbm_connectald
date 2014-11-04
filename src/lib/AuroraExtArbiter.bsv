import FIFO::*;
import FIFOF::*;
import Vector::*;
import RWire::*;

import AuroraExtImport::*;
import AuroraCommon::*;
import AuroraExtGearbox::*;

typedef 6 HeaderFieldSz;
typedef TSub#(AuroraIfcWidth, TMul#(HeaderFieldSz, 4)) PayloadSz;
typedef struct {
	Bit#(PayloadSz) payload;
	Bit#(HeaderFieldSz) len; // not used now
	Bit#(HeaderFieldSz) ptype;
	Bit#(HeaderFieldSz) src;
	Bit#(HeaderFieldSz) dst;
} AuroraPacket deriving (Bits,Eq);
function Bit#(AuroraIfcWidth) packPacket(AuroraPacket packet);
	Bit#(AuroraIfcWidth) p = {
		packet.payload,
		packet.len,
		packet.ptype,
		packet.src,
		packet.dst
	};
	return p;
endfunction
function AuroraPacket unpackPacket(Bit#(AuroraIfcWidth) d);
	AuroraPacket packet;
	packet.dst = truncate(d);
	packet.src = truncate(d>>valueOf(HeaderFieldSz));
	packet.ptype = truncate(d>>(2*valueOf(HeaderFieldSz)));
	packet.len = truncate(d>>(3*valueOf(HeaderFieldSz)));
	packet.payload = truncate(d>>(4*valueOf(HeaderFieldSz)));
	return packet;
endfunction

interface AuroraEndpointUserIfc#(type t);
	method Action send(t data, Bit#(HeaderFieldSz) dst);
	method ActionValue#(Tuple2#(t, Bit#(HeaderFieldSz))) receive;
endinterface
interface AuroraEndpointCmdIfc;
	interface AuroraExtUserIfc user;
	//method Action send(AuroraIfcType data);
	//method ActionValue#(AuroraIfcType) receive;
	method Bit#(6) portIdx;
endinterface

interface AuroraEndpointIfc#(type t);
interface AuroraEndpointUserIfc#(t) user;
interface AuroraEndpointCmdIfc cmd;
endinterface
module mkAuroraEndpoint#(Integer pidx, Reg#(Bit#(HeaderFieldSz)) myNetIdx) ( AuroraEndpointIfc#(t) )
	provisos(Bits#(t,wt)
		, Add#(wt,__a,PayloadSz));

	FIFO#(AuroraIfcType) sendQ <- mkFIFO;
	FIFO#(AuroraIfcType) recvQ <- mkFIFO;
	Reg#(Bit#(6)) myIdx <- mkReg(fromInteger(pidx));
interface AuroraEndpointUserIfc user;
	method Action send(t data, Bit#(HeaderFieldSz) dst);
		AuroraPacket p;
		p.dst = dst;
		p.src = myNetIdx;
		p.payload = zeroExtend(pack(data));
		p.len = 1;
		p.ptype = fromInteger(pidx);
		sendQ.enq(packPacket(p));
	endmethod
	method ActionValue#(Tuple2#(t, Bit#(HeaderFieldSz))) receive;
		recvQ.deq;
		AuroraIfcType idata = recvQ.first;
		AuroraPacket p = unpackPacket(idata);
		t data = unpack(truncate(p.payload));
		Bit#(HeaderFieldSz) src = p.src;
		return tuple2(data,src);
	endmethod
endinterface
interface AuroraEndpointCmdIfc cmd;
	interface AuroraExtUserIfc user;
		method Action send(AuroraIfcType data);
			recvQ.enq(data);
		endmethod
		method ActionValue#(AuroraIfcType) receive;
			sendQ.deq;
			return sendQ.first;
		endmethod
		method Bit#(1) lane_up;
			return 1;
		endmethod
		method Bit#(1) channel_up;
			return 1;
		endmethod

	endinterface
	method Bit#(6) portIdx;
		return myIdx;
	endmethod
endinterface
endmodule

interface FIFODeqIfc;
	method Action deq;
endinterface
interface FIFOMD #(type t, /*type tdst, */numeric type ports);
	method Action enq(t d);
	method Maybe#(t) first;
	interface Vector#(ports, FIFODeqIfc) deqs;
endinterface

module mkFIFOMD (FIFOMD#(t,ports))
	provisos(Bits#(t,wt)
		);

	FIFOF#(t) dataQ <- mkSizedFIFOF(8);
	Vector#(ports,Wire#(Bool)) deqWires <- replicateM(mkDWire(False));

	rule deqrule;
		Bool deqreq = False;
		for ( Integer i = 0; i < valueOf(ports); i = i + 1 ) begin
			deqreq = deqreq || deqWires[i];
		end
		//Bool deqreq = fold(funcOr, deqWires);
		if ( deqreq ) begin
			dataQ.deq;
		end
	endrule

	Vector#(ports, FIFODeqIfc) deqifc;

	for ( Integer idx = 0; idx < valueOf(ports); idx = idx + 1) begin
		deqifc[idx] = interface FIFODeqIfc;
			method Action deq;
			deqWires[idx] <= True;
			endmethod
		endinterface: FIFODeqIfc;
	end
	method Action enq(t d);
		dataQ.enq(d);
	endmethod
	method Maybe#(t) first;
		Maybe#(t) fd = tagged Invalid;
		if ( dataQ.notEmpty ) fd = tagged Valid dataQ.first;
		return fd;
	endmethod
	interface deqs = deqifc;
endmodule

interface XBarInPortIfc #(type tData, type tDst);
	method Action send(tData data, tDst dst);
endinterface
interface XBarOutPortIfc #(type tData);
	method ActionValue#(tData) receive;
	method Bool notEmpty;
endinterface

interface XBarIfc #(numeric type inPorts, numeric type outPorts, type tData, type tDst);
	interface Vector#(inPorts, XBarInPortIfc#(tData, tDst)) userIn;
	interface Vector#(outPorts, XBarOutPortIfc#(tData)) userOut;
endinterface

module mkXBar (XBarIfc#(inPorts, outPorts, tData, tDst))
	provisos(
		Bits#(tData, tDataSz), 
		Bits#(tDst, tDstSz), 
		Arith#(tDst),
		Ord#(tDst),
		PrimIndex#(tDst, tDstI)
		);
	Vector#(inPorts, FIFOMD#(tData, outPorts)) vBuffer <- replicateM(mkFIFOMD);
	Vector#(inPorts, FIFOMD#(tDst, outPorts)) vDst <- replicateM(mkFIFOMD);
	Vector#(outPorts, FIFOF#(tData)) vDstPortQ <- replicateM(mkFIFOF);

	for ( Integer pidx = 0; pidx < valueOf(outPorts); pidx = pidx + 1 ) begin
		Reg#(tDst) curPrioInPort <- mkReg(fromInteger(pidx));
		FIFO#(tDst) readSrcQ <- mkFIFO;
		rule relayOut;
			Maybe#(tDst) srcIdx = tagged Invalid;
			for ( Integer i = 0; i < valueof(inPorts); i = i + 1) begin
				tDst checkInPort = fromInteger(i);
				
				let dstm = vDst[checkInPort].first;
				if ( isValid(dstm) ) begin
					if ( !isValid(srcIdx) || checkInPort == curPrioInPort ) begin

						let dst = fromMaybe(?,dstm);
						if ( dst == fromInteger(pidx) ) begin
							srcIdx = tagged Valid checkInPort;
						end
					end
				end
			end
			
			if ( isValid(srcIdx) ) begin
				let inidx = fromMaybe(?,srcIdx);
				vDst[inidx].deqs[pidx].deq;
				readSrcQ.enq(inidx);
			end
			
			if (curPrioInPort + 1 >= fromInteger(valueOf(inPorts)) )
				curPrioInPort <= 0;
			else 
				curPrioInPort <= curPrioInPort + 1;
		endrule
		rule relayData2;
			let inidx = readSrcQ.first;
			readSrcQ.deq;

			vBuffer[inidx].deqs[pidx].deq;
			let packetdm = vBuffer[inidx].first;
			let packetd = fromMaybe(?,packetdm);
			vDstPortQ[pidx].enq(packetd);
		endrule
	end

	Vector#(inPorts, XBarInPortIfc#(tData,tDst)) usersin;
	Vector#(outPorts, XBarOutPortIfc#(tData)) usersout;

	for ( Integer idx = 0; idx < valueOf(inPorts); idx = idx + 1) begin
		usersin[idx] = interface XBarInPortIfc#(tData, tDst);
		method Action send(tData data, tDst dst);
			vBuffer[idx].enq(data);
			vDst[idx].enq(dst);
		endmethod
		endinterface:XBarInPortIfc;
	end
	for ( Integer idx = 0; idx < valueOf(outPorts); idx = idx + 1) begin
		usersout[idx] = interface XBarOutPortIfc#(tData);
		method ActionValue#(tData) receive;
			vDstPortQ[idx].deq;
			return vDstPortQ[idx].first;
		endmethod
		method Bool notEmpty;
			return vDstPortQ[idx].notEmpty;
		endmethod
		endinterface: XBarOutPortIfc;
	end
	interface Vector userIn = usersin;
	interface Vector userOut = usersout;
endmodule

typedef 20 NodeCount;

interface AuroraExtArbiterIfc;
	method Action setRoutingTable(Bit#(6) node, Bit#(8) portidx);
endinterface

module mkAuroraExtArbiter#(Vector#(tPortCount, AuroraExtUserIfc) extports, Vector#(tEndpointCount, AuroraEndpointCmdIfc) endpoints, Reg#(Bit#(HeaderFieldSz)) myIdx) (AuroraExtArbiterIfc)
	provisos(
	NumAlias#(TAdd#(tPortCount,tEndpointCount),tTotalInCount));

	Integer endpointCount = valueOf(tEndpointCount);
	Integer portCount = valueOf(tPortCount);
	Integer totalInCount = valueOf(tTotalInCount);

	//function AuroraExtUserIfc uifc(AuroraEndpointCmdIfc cmd) = cmd.user;
	//Vector#(tTotalInCount, AuroraExtUserIfc) ports = append(extports, map(uifc,endpoints));

	//NOTE: routingTable contains a bitmap of valid aurora ports to a node
	//Important: all ports in a bitmap should connect to the same immediate neighboring node
	//so that all packets take the same path to the destination
	//FIXME right now it's just used as an index map
	Vector#(NodeCount, Reg#(Bit#(8))) routingTable <- replicateM(mkReg(0));

	XBarIfc#(tPortCount, tPortCount,AuroraPacket, Bit#(HeaderFieldSz)) xbarPP <- mkXBar;
	XBarIfc#(tEndpointCount, tEndpointCount,AuroraPacket, Bit#(HeaderFieldSz)) xbarEE <- mkXBar;
	
	XBarIfc#(tEndpointCount, tPortCount,AuroraPacket, Bit#(HeaderFieldSz)) xbarEP <- mkXBar;
	XBarIfc#(tPortCount, tEndpointCount,AuroraPacket, Bit#(HeaderFieldSz)) xbarPE <- mkXBar;

	function Bit#(HeaderFieldSz) mapDstToPort(Bit#(HeaderFieldSz) dst);
		//FIXME
		Bit#(HeaderFieldSz) ret = truncate(routingTable[dst]);
		return ret;
	endfunction
	
	for ( Integer idx = 0; idx < endpointCount; idx = idx + 1) begin
		rule recvInDataEP;
			let d <- endpoints[idx].user.receive;
			AuroraPacket packet = unpackPacket(d);
			if ( packet.dst == myIdx ) begin
				xbarEE.userIn[idx].send(packet, packet.ptype);
			end else begin
				let dstport = mapDstToPort(packet.dst);
				xbarEP.userIn[idx].send(packet, dstport);
			end
		endrule

		Reg#(Bool) prioEP <- mkReg(False);
		rule forwardOutDataEP;
			if ( prioEP ) begin
				if ( xbarEE.userOut[idx].notEmpty ) begin
					let d <- xbarEE.userOut[idx].receive;
					let rp = packPacket(d);
					endpoints[idx].user.send(rp);
				end else if (xbarPE.userOut[idx].notEmpty) begin
					let d <- xbarPE.userOut[idx].receive;
					let rp = packPacket(d);
					endpoints[idx].user.send(rp);
				end
			end else begin
				if ( xbarPE.userOut[idx].notEmpty ) begin
					let d <- xbarPE.userOut[idx].receive;
					let rp = packPacket(d);
					endpoints[idx].user.send(rp);
				end else if (xbarEE.userOut[idx].notEmpty) begin
					let d <- xbarEE.userOut[idx].receive;
					let rp = packPacket(d);
					endpoints[idx].user.send(rp);
				end
			end
		endrule
	end
	
	for ( Integer idx = 0; idx < portCount; idx = idx + 1) begin
		rule recvInDataP;
			let d <- extports[idx].receive;
			AuroraPacket packet = unpackPacket(d);
			if ( packet.dst == myIdx ) begin
				xbarPE.userIn[idx].send(packet, packet.ptype);
			end else begin
				let dstport = mapDstToPort(packet.dst);
				xbarPP.userIn[idx].send(packet, dstport);
			end
		endrule

		Reg#(Bool) prioEP <- mkReg(False);
		rule forwardOutDataP;
			if ( prioEP ) begin
				if ( xbarEP.userOut[idx].notEmpty ) begin
					let d <- xbarEP.userOut[idx].receive;
					let rp = packPacket(d);
					extports[idx].send(rp);
				end else if (xbarPP.userOut[idx].notEmpty) begin
					let d <- xbarPP.userOut[idx].receive;
					let rp = packPacket(d);
					extports[idx].send(rp);
				end
			end else begin
				if ( xbarPP.userOut[idx].notEmpty ) begin
					let d <- xbarPP.userOut[idx].receive;
					let rp = packPacket(d);
					extports[idx].send(rp);
				end else if (xbarEP.userOut[idx].notEmpty) begin
					let d <- xbarEP.userOut[idx].receive;
					let rp = packPacket(d);
					extports[idx].send(rp);
				end
			end
		endrule
	end


	method Action setRoutingTable(Bit#(6) node, Bit#(8) portmap);
		routingTable[node] <= portmap;
	endmethod
endmodule

