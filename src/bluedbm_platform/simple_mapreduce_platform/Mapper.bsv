package Mapper;

import MRTypes::*;

import FIFO::*;
import Vector::*;

module mkMapper (MapperIfc);
	FIFO#(MapHeader) rfQ <- mkFIFO();
	method ActionValue#(ReduceHeader) getKV;
		rfQ.deq;
		MapHeader mh = rfQ.first;
		//$display("%h %h %h %h\n", mh.key, mh.value8[0], mh.value8[1], mh.value4[0]);
		ReduceHeader rd = unpack(0);
		rd.key = mh.key;
		rd.valid = True;
		return rd;
	endmethod
	method Action putKV(MapHeader header);
		rfQ.enq(header);
	endmethod
	method Bool available;
		return True;
	endmethod
endmodule


endpackage: Mapper
