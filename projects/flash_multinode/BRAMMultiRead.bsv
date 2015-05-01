import BRAM::*;
import Vector::*;


//1 write, N read port BRAM via replication

interface BRAMMultiRead#(type addr, type data, numeric type nreadPorts);
	interface Vector#(nreadPorts, BRAMServer#(addr, data)) rport;
	interface BRAMServer#(addr, data) wport;
endinterface

module mkBRAMMultiRead#(BRAM_Configure cfg) (BRAMMultiRead#(addr, data, nreadPorts))
	provisos (Bits#(addr, a__),
  				 Bits#(data, b__));
	
	Vector#(nreadPorts, BRAM2Port#(addr, data)) brams <- replicateM(mkBRAM2Server(cfg));
	
	Vector#(nreadPorts, BRAMServer#(addr, data)) rportV = newVector();
	for (Integer i=0; i<valueOf(nreadPorts); i=i+1) begin
		rportV[i] = brams[i].portB;
	end

	interface rport = rportV;
	interface BRAMServer wport;
		interface Put request;
			method Action put(BRAMRequest#(addr, data) req);
				for (Integer i=0; i<valueOf(nreadPorts); i=i+1) begin
					brams[i].portA.request.put(req);
				end
			endmethod
		endinterface
		interface response = ?;
	endinterface
endmodule

