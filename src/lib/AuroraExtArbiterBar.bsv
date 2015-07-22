// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import FIFO::*;
import SpecialFIFOs::*;
import FIFOF::*;
import BRAMFIFO::*;
import Vector::*;
import RegFile::*;

import AuroraExtImport::*;
import AuroraCommon::*;
import AuroraExtEndpoint::*;
import Merge2::*;

interface AuroraExtArbiterBarIfc;
	method Action setMyId(HeaderField myId);
endinterface

module mkAuroraExtArbiterBar#(Vector#(tExtCount, AuroraExtUserIfc) extPorts, Vector#(tEndpointCount, AuroraEndpointCmdIfc) endpoints) (AuroraExtArbiterBarIfc);
//module mkAuroraExtArbiterBar#(Vector#(2, AuroraExtUserIfc) pUp, Vector#(2, AuroraExtUserIfc) pDown, Vector#(tEndpointCount, AuroraEndpointCmdIfc) endpoints) (AuroraExtArbiterBarIfc);
	Vector#(2, AuroraExtUserIfc) pUp;
	Vector#(2, AuroraExtUserIfc) pDown;
	pUp[0] = extPorts[0]; pUp[1] = extPorts[1];
	pDown[0] = extPorts[3]; pDown[1] = extPorts[2]; // port 3 goes to node N-1's port 0, port 2 goes to N-1's port 1
	
	Integer endpointCount = valueOf(tEndpointCount);

	Reg#(Maybe#(HeaderField)) myId <- mkReg(tagged Invalid);

	Reg#(Bit#(1)) outQupOff <- mkReg(0);
	Reg#(Bit#(1)) inQupOff <- mkReg(0);
	Reg#(Bit#(1)) outQdownOff <- mkReg(0);
	Reg#(Bit#(1)) inQdownOff <- mkReg(0);

	FIFO#(AuroraPacket) outQup <- mkPipelineFIFO;
	FIFO#(AuroraPacket) inQup <- mkPipelineFIFO;
	FIFO#(AuroraPacket) outQdown <- mkPipelineFIFO;
	FIFO#(AuroraPacket) inQdown <- mkPipelineFIFO;
	rule scatterOutUp;
		if ( outQupOff == 0 ) begin
			outQupOff <= 1;
			pUp[0].send(outQup.first);
			outQup.deq;
		end else if ( outQupOff == 1 ) begin
			outQupOff <= 0;
			pUp[1].send(outQup.first);
			outQup.deq;
		end
	endrule
	rule collectInUp;
		if ( inQupOff == 0 ) begin
			let d <- pUp[0].receive;
			inQup.enq(d);
			inQupOff <= 1;
		end else if ( inQupOff == 1 ) begin
			let d <- pUp[1].receive;
			inQup.enq(d);
			inQupOff <= 0;
		end
	endrule
	rule scatterOutDown;
		if ( outQdownOff == 0 ) begin
			outQdownOff <= 1;
			pDown[0].send(outQdown.first);
			outQdown.deq;
		end else if ( outQdownOff == 1 ) begin
			outQdownOff <= 0;
			pDown[1].send(outQdown.first);
			outQdown.deq;
		end
	endrule
	rule collectInDown;
		if ( inQdownOff == 0 ) begin
			inQdownOff <= 1;
			let d <- pDown[0].receive;
			inQdown.enq(d);
		end else if ( inQdownOff == 1 ) begin
			inQdownOff <= 0;
			let d <- pDown[1].receive;
			inQdown.enq(d);
		end
	endrule
	
	FIFO#(AuroraPacket) outQep <- mkPipelineFIFO;
	FIFO#(AuroraPacket) inQep <- mkPipelineFIFO;

	Merge2Ifc#(AuroraPacket) mergeUpOut <- mkMerge2;
	Merge2Ifc#(AuroraPacket) mergeDownOut <- mkMerge2;
	Merge2Ifc#(AuroraPacket) mergeEpOut <- mkMerge2;

	rule handleUpIn ( isValid(myId) );
		let myid = fromMaybe(?, myId);
		inQup.deq;
		let d = inQup.first;
		if ( d.dst == myid ) begin
			if ( d.src != myid ) begin // This should not happen
				mergeEpOut.enq1(d);
			end
		end else begin
			//mergeUpOut.enq1(d);
			mergeDownOut.enq1(d);
		end
	endrule
	rule relayUp;
		let d = mergeUpOut.first;
		mergeUpOut.deq;
		outQup.enq(d);
	endrule
	rule handleDownIn( isValid(myId) );
		let myid = fromMaybe(?, myId);
		inQdown.deq;
		let d = inQdown.first;
		if ( d.dst == myid ) begin
			if ( d.src != myid ) begin // This should not happen 
				mergeEpOut.enq2(d);
			end
		end else begin
			//mergeDownOut.enq1(d);
			mergeUpOut.enq1(d);
		end
	endrule
	rule relayDown;
		let d = mergeDownOut.first;
		mergeDownOut.deq;
		outQdown.enq(d);
	endrule
	rule handleEpIn( isValid(myId) );
		let myid = fromMaybe(?, myId);
		inQep.deq;
		let d_ = inQep.first;

		// 
		AuroraPacket d;
		d.payload = d_.payload;
		d.src = myid;
		d.dst = d_.dst;
		d.ptype = d_.ptype;

		//NOTE: d.dst == myid gets dropped!
		if ( d.dst > myid ) begin
			mergeUpOut.enq2(d);
		end else if ( d.dst < myid ) begin
			mergeDownOut.enq2(d);
		end
	endrule
	rule relayEp;
		let d = mergeEpOut.first;
		mergeEpOut.deq;
		outQep.enq(d);
	endrule

	if (endpointCount == 0) begin
		// do nothing
	end else if (endpointCount == 1) begin
		AuroraEndpointCmdIfc ep = endpoints[0];
		rule rout;
			outQep.deq;
			ep.send(outQep.first);
		endrule
		rule rin;
			let d <- ep.receive;
			inQep.enq(d);
		endrule
	end else begin
		Vector#(TSub#(tEndpointCount, 1), Merge2Ifc#(AuroraPacket)) vMerge <- replicateM(mkMerge2);

		rule rOut;
			outQep.deq;
			let d = outQep.first;
			let ptype = d.ptype;
			endpoints[ptype].send(d);
			//$display( "ep %d recv data %x", d.ptype, d.payload );
			/*
			for ( Integer eidx = 0; eidx < endpointCount; eidx=eidx+1) begin
				if ( endpoints[eidx].packetType == ptype ) begin
					endpoints[eidx].send(d);
				end
			end
			*/
		endrule



		rule rin0;
			let d_ <- endpoints[0].receive;
			// 
			AuroraPacket d;
			d.payload = d_.payload;
			d.src = d_.src;
			d.dst = d_.dst;
			d.ptype = 0;

			vMerge[0].enq2(d);
		endrule
		for ( Integer eidx = 1; eidx < endpointCount; eidx=eidx+1 ) begin
			rule rinn;
				let d_ <- endpoints[eidx].receive;
				// 
				AuroraPacket d;
				d.payload = d_.payload;
				d.src = d_.src;
				d.dst = d_.dst;
				d.ptype = fromInteger(eidx);
				vMerge[eidx-1].enq1(d);
			endrule
		end

		for ( Integer eidx = 1; eidx < endpointCount-1; eidx=eidx+1 ) begin
			rule rell;
				let d = vMerge[eidx-1].first;
				vMerge[eidx-1].deq;
				vMerge[eidx].enq2(d);
			endrule
		end

		rule relayIn;
			let d = vMerge[endpointCount-2].first;
			vMerge[endpointCount-2].deq;
			inQep.enq(d);
			//$display( "ep %d sends data %x", d.ptype, d.payload );
		endrule
	end

	
	method Action setMyId(HeaderField myId_);
		myId <= tagged Valid myId_;
	endmethod
endmodule
