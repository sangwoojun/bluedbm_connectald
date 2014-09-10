import MRTypes::*;

interface PlatformIndication;
	method Action sendWord8(Bit#(64) word);
	method Action sendWord4(Bit#(32) word);
	method Action sendKey(Bit#(64) key);

	method Action mrDone(Bit#(32) dummy);

	method Action rawWordTest(Bit#(64) data);

	method Action requestWords(Bit#(32) words);
endinterface

interface PlatformRequest;
	method Action sendWord8(Bit#(64) word);
	method Action sendWord4(Bit#(32) word);
	method Action sendKey(Bit#(64) key);
	method Action finalize(Bit#(32) dummy);

	method Action start(Bit#(32) dummy);
	method Action rawWordRequest(Bit#(64) data);
endinterface
