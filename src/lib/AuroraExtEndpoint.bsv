// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

/*/////////////////////////////////////////////////
mkAuroraEndpointRaw
	No end-to-end flow control
	Best latency and bandwidth, as long as data is always drained at the sink
	WARNING: 
	This can cause deadlocks across the network if data is not always drained! 

mkAuroraEndpointStatic#(Integer qSize, Integer flowStride_) 
	(qSize*NodeCount) buffers are allocated.
	flowStride is the unit of flow control credits
	flowStride MUST BE SMALLER than qSize
	
	qSize has to be large enough to have high bandwidth, which means a lot of buffers have to be allocated.
	Best if all nodes are expected to send data to one sink at the same time

mkAuroraEndpointDynamic#(Integer qSize, Integer flowStride_, Integer extraSize_)
	(qSize*NodeCount + extraSize) buffers are allocated.
	flowStride is the unit of flow control credits
	flowStride CAN BE LARGER than qSize

	buffers are dynamically allocated whenever available,
	and flow control tokens are sent accordingly.
	Best if not too many nodes are contending for one sink.
	(extraSize/flowStride) number of nodes can be sending to a single sink
	simultaneously.

	WARNING: To be effective, data must be sent in flowStride bursts
	(it's okay to be incontiguous)
	When an endpoint receives a token and doesn't consume all of its budget,
	that buffer resource cannot be allocated to another waiting endpoint

*/////////////////////////////////////////////////

import FIFO::*;
import FIFOF::*;
import BRAMFIFO::*;
import Vector::*;
import RegFile::*;

import AuroraExtImport::*;
import AuroraCommon::*;

typedef 5 HeaderFieldSz;
typedef Bit#(HeaderFieldSz) HeaderField;

typedef `NodeCountLog NodeCountLog;
typedef TExp#(NodeCountLog) NodeCount;

interface AuroraEndpointUserIfc#(type t);
	method Action send(t data, Bit#(HeaderFieldSz) dst);
	method ActionValue#(Tuple2#(t, Bit#(HeaderFieldSz))) receive;
endinterface
interface AuroraEndpointCmdIfc;
	method Action send(AuroraPacket data);
	method ActionValue#(AuroraPacket) receive;
	//method HeaderField packetType;
endinterface
interface AuroraEndpointIfc#(type t);
interface AuroraEndpointUserIfc#(t) user;
interface AuroraEndpointCmdIfc cmd;
endinterface

module mkAuroraEndpointRaw (AuroraEndpointIfc#(t))
	provisos(
		Bits#(t, ts),
		Add#(ts, a__, PayloadSz));

	FIFO#(Tuple2#(t, HeaderField)) sendQ <- mkFIFO;
	FIFO#(Tuple2#(t, HeaderField)) recvQ <- mkFIFO;

interface AuroraEndpointUserIfc user;
	method Action send(t data, Bit#(HeaderFieldSz) dst);
		sendQ.enq(tuple2(data,dst));
	endmethod
	method ActionValue#(Tuple2#(t, Bit#(HeaderFieldSz))) receive;
		recvQ.deq;
		return recvQ.first;
	endmethod
endinterface
interface AuroraEndpointCmdIfc cmd;
	method Action send(AuroraPacket data);
		recvQ.enq(tuple2(unpack(truncate(data.payload)), data.src));
	endmethod
	method ActionValue#(AuroraPacket) receive;
		let s = sendQ.first;
		sendQ.deq;
		let dt = pack(tpl_1(s));
		let dst = tpl_2(s);

		AuroraPacket d;
		d.payload = zeroExtend(dt);
		d.dst = dst;
		d.src = ?; // This is filled in at the arbiter
		d.ptype = 0; // This is filled in at the arbiter (0 is when this is the only ep) //fromInteger(ptype);

		return d;
	endmethod
endinterface
endmodule

module mkAuroraEndpointDynamic#(Integer qSize, Integer flowStride_, Integer extraSize_) (AuroraEndpointIfc#(t))
	provisos(
		Bits#(t, ts),
		Add#(b__, ts, 174), //FIXME!!!!!!!!!!!!
		Add#(ts,1,ts1),
		Add#(ts1, a__, PayloadSz));
	
	Integer nodeCount = valueOf(NodeCount);

	Integer extraSize = extraSize_;
	Integer flowStride = flowStride_;

	if ( extraSize < flowStride ) extraSize = flowStride;
	
	Integer recvQDepth = nodeCount*qSize + extraSize;



	Vector#(NodeCount, Reg#(Bit#(16))) sendBudgetUp <- replicateM(mkReg(fromInteger(qSize)));
	Vector#(NodeCount, Reg#(Bit#(16))) sendBudgetDown <- replicateM(mkReg(0));

	FIFO#(Tuple2#(t, HeaderField)) sendQ <- mkFIFO;
	FIFO#(AuroraPacket) packetSendQ <- mkFIFO;
	FIFO#(Tuple2#(t, HeaderField)) recvQ;
	if ( recvQDepth <= 256 ) begin
		recvQ <- mkSizedFIFO(recvQDepth);
	end else begin
		recvQ <- mkSizedBRAMFIFO(recvQDepth);
	end
	FIFOF#(HeaderField) ackQ <- mkSizedFIFOF(nodeCount*(1+(qSize/flowStride)));

	Reg#(Bit#(16)) recvQAvailUp <- mkReg(fromInteger(extraSize));
	Reg#(Bit#(16)) recvQAvailDown <- mkReg(0);
	rule insertAckQ;
		let recvQAvail = recvQAvailUp - recvQAvailDown;

		if ( ackQ.notEmpty && recvQAvail >= fromInteger(flowStride) ) begin
			ackQ.deq;

			AuroraPacket d;
			d.payload = 1; // control
			d.dst = ackQ.first;
			d.src = ?; // This is filled in at the arbiter
			d.ptype = 0; // This is filled in at the arbiter (0 is when this is the only ep) //fromInteger(ptype);
			
			recvQAvailDown <= recvQAvailDown + fromInteger(flowStride);

			packetSendQ.enq(d);
		end else begin
			let s = sendQ.first;
			let dt = pack(tpl_1(s));
			let dst = tpl_2(s);
			Bit#(NodeCountLog) dstm = truncate(dst);

			if ( sendBudgetUp[dstm] - sendBudgetDown[dstm] > 0 ) begin
				sendBudgetDown[dstm] <= sendBudgetDown[dstm] + 1;
				//tempThrottleQ[dst].enq(True);

				sendQ.deq;

				AuroraPacket d;
				Payload dt_ = zeroExtend(dt); // FIXME this may lose MSB if dt is too large
				d.payload = (dt_<<1);
				d.dst = dst;
				d.src = ?; // This is filled in at the arbiter
				d.ptype = 0; // This is filled in at the arbiter (0 is when this is the only ep) //fromInteger(ptype);
				packetSendQ.enq(d);
			end
		
		end

	endrule

	Vector#(NodeCount, Reg#(Bit#(16))) flowStrideCounter <- replicateM(mkReg(fromInteger(flowStride - 1)));
	
interface AuroraEndpointUserIfc user;
	method Action send(t data, Bit#(HeaderFieldSz) dst);// if ( sendBudget.sub(dst) > 0 );
		sendQ.enq(tuple2(data,dst));
	endmethod
	method ActionValue#(Tuple2#(t, Bit#(HeaderFieldSz))) receive;
		// send ack to src
		let d_ = recvQ.first;
		let data = tpl_1(d_);
		let src = tpl_2(d_);
		Bit#(NodeCountLog) srcm = truncate(src);

		recvQAvailUp <= recvQAvailUp + 1;

		if ( flowStrideCounter[srcm] +1 >= fromInteger(flowStride) ) begin
			ackQ.enq(src);
			flowStrideCounter[srcm] <= 0;
		end else begin
			flowStrideCounter[srcm] <= flowStrideCounter[srcm]+1;
		end
		//$display ( "enqing ack packet to %d", src );


		recvQ.deq;
		return d_;
	endmethod
endinterface
interface AuroraEndpointCmdIfc cmd;
	method Action send(AuroraPacket data);
		// if ack then inc budget
		let payload = data.payload;
		Bit#(NodeCountLog) srcm = truncate(data.src);

		if ( payload[0] == 1 ) begin
			sendBudgetUp[srcm] <= sendBudgetUp[srcm]+fromInteger(flowStride);
			//tempThrottleQ[data.src].deq;
		end else begin
			recvQ.enq(tuple2(unpack(truncate(data.payload>>1)), data.src));
		end
	endmethod
	method ActionValue#(AuroraPacket) receive;
		let d = packetSendQ.first;
		packetSendQ.deq;

		return d;
	endmethod
	/*
	method HeaderField packetType;
		return fromInteger(ptype);
	endmethod
	*/
endinterface
endmodule

module mkAuroraEndpointStatic#(Integer qSize, Integer flowStride_) (AuroraEndpointIfc#(t))
	provisos(
		Bits#(t, ts),
		Add#(b__, ts, 174), //FIXME!!!!!!!!!!!!
		Add#(ts,1,ts1),
		Add#(ts1, a__, PayloadSz));
	
	Integer nodeCountLog = valueOf(NodeCountLog);
	Integer nodeCount = valueOf(NodeCount);

	Integer recvQDepth = nodeCount*qSize;

	//NOTE: flowstride needs to be smaller or equal to qSize!
	Integer flowStride = flowStride_;
	if ( flowStride_ > qSize ) flowStride = qSize;

	Vector#(NodeCount, Reg#(Bit#(16))) sendBudgetUp <- replicateM(mkReg(fromInteger(qSize)));
	Vector#(NodeCount, Reg#(Bit#(16))) sendBudgetDown <- replicateM(mkReg(0));

	FIFO#(Tuple2#(t, HeaderField)) sendQ <- mkFIFO;
	FIFO#(AuroraPacket) packetSendQ <- mkFIFO;
	FIFO#(Tuple2#(t, HeaderField)) recvQ;
	if ( qSize <= 8 ) begin
		recvQ <- mkSizedFIFO(recvQDepth);
	end else begin
		recvQ <- mkSizedBRAMFIFO(recvQDepth);
	end
	FIFOF#(HeaderField) ackQ <- mkSizedFIFOF(nodeCount*(1+(qSize/flowStride)));
	rule insertAckQ;

		if ( ackQ.notEmpty ) begin
			ackQ.deq;

			AuroraPacket d;
			d.payload = 1; // control
			d.dst = ackQ.first;
			d.src = ?; // This is filled in at the arbiter
			d.ptype = 0; // This is filled in at the arbiter (0 is when this is the only ep) //fromInteger(ptype);
			packetSendQ.enq(d);
		end else begin
			let s = sendQ.first;
			let dt = pack(tpl_1(s));
			let dst = tpl_2(s);
			Bit#(NodeCountLog) dstm = truncate(dst);

			if ( sendBudgetUp[dstm] - sendBudgetDown[dstm] > 0 ) begin
				sendBudgetDown[dstm] <= sendBudgetDown[dstm] + 1;
				//tempThrottleQ[dst].enq(True);

				sendQ.deq;

				AuroraPacket d;
				Payload dt_ = zeroExtend(dt); // FIXME this may lose MSB if dt is too large
				d.payload = (dt_<<1);
				d.dst = dst;
				d.src = ?; // This is filled in at the arbiter
				d.ptype = 0; // This is filled in at the arbiter (0 is when this is the only ep) //fromInteger(ptype);
				packetSendQ.enq(d);
			end
		
		end

	endrule

	Vector#(NodeCount, Reg#(Bit#(16))) flowStrideCounter <- replicateM(mkReg(0));
	
interface AuroraEndpointUserIfc user;
	method Action send(t data, Bit#(HeaderFieldSz) dst);// if ( sendBudget.sub(dst) > 0 );
		sendQ.enq(tuple2(data,dst));
	endmethod
	method ActionValue#(Tuple2#(t, Bit#(HeaderFieldSz))) receive;
		// send ack to src
		let d_ = recvQ.first;
		let data = tpl_1(d_);
		let src = tpl_2(d_);
		Bit#(NodeCountLog) srcm = truncate(src);

		if ( flowStrideCounter[srcm] +1 >= fromInteger(flowStride) ) begin
			ackQ.enq(src);
			flowStrideCounter[srcm] <= 0;
		end else begin
			flowStrideCounter[srcm] <= flowStrideCounter[srcm]+1;
		end
		//$display ( "enqing ack packet to %d", src );


		recvQ.deq;
		return d_;
	endmethod
endinterface
interface AuroraEndpointCmdIfc cmd;
	method Action send(AuroraPacket data);
		// if ack then inc budget
		let payload = data.payload;
		Bit#(NodeCountLog) srcm = truncate(data.src);
		
		if ( payload[0] == 1 ) begin
			sendBudgetUp[srcm] <= sendBudgetUp[srcm]+fromInteger(flowStride);
			//tempThrottleQ[data.src].deq;
		end else begin
			recvQ.enq(tuple2(unpack(truncate(data.payload>>1)), data.src));
		end
	endmethod
	method ActionValue#(AuroraPacket) receive;
		let d = packetSendQ.first;
		packetSendQ.deq;

		return d;
	endmethod
	/*
	method HeaderField packetType;
		return fromInteger(ptype);
	endmethod
	*/
endinterface
endmodule



