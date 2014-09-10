package MRTypes;

import Vector::*;

typedef 2 Map8ByteCount;
typedef 1 Map4ByteCount;

typedef struct {
	Bit#(64) key;
	Vector#(Map8ByteCount, Bit#(64)) value8;
	Vector#(Map4ByteCount, Bit#(32)) value4;
} MapHeader deriving(Bits,Eq);

typedef SizeOf#(MapHeader) MapHeaderSz;
//typedef TDiv#(MapHeaderSz, 8) MapHeaderWords;

typedef struct {
	Bool valid;
	Bit#(64) key;
	Bit#(64) value;
} ReduceHeader deriving(Bits,Eq);

typedef SizeOf#(ReduceHeader) ReduceHeaderSz;

typedef struct {
	Bit#(64) key; 

	Bit#(64) count;
} ReducerContext deriving(Bits,Eq);

typedef SizeOf#(ReducerContext) ReducerContextSz;

typedef struct {
	Bool valid;
	Bit#(64) key;

	Bit#(64) value;
} ReducerResult deriving(Bits,Eq);

interface MapperIfc;
	method ActionValue#(ReduceHeader) getKV;
	method Action putKV(MapHeader header);
	method Bool available;
endinterface
interface ReducerIfc;
	method Action putKV(ReduceHeader header, ReducerContext ctx);
	method ActionValue#(Tuple2#(ReducerResult, ReducerContext)) getResult;
endinterface
interface FinalizerIfc;
	method Action putCtx(ReducerContext ctx);
endinterface
endpackage: MRTypes
