package AuroraController;

interface AuroraControllerIfc;
	method Action send(Bit#(6) dst, Bit#(6) src, Bit#(6) count, Bit#(6) port);
	method Action sendData(Bit#(64) data);
endinterface

module mkAuroraController (AuroraControllerIfc);
endmodule


endpackage: AuroraController
