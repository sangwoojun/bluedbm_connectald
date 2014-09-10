interface PlatformIndication;
	method Action rawWordTest(Bit#(64) data);

	method Action i2cResult(Bit#(32) data);
endinterface

interface PlatformRequest;
	method Action rawWordRequest(Bit#(64) data);
	method Action i2cRequest(Bit#(32) request);
	method Action start(Bit#(32) dummy);
	method Action resetAurora(Bit#(32) dummy);
	method Action auroraStatus(Bit#(32) dummy);
endinterface
