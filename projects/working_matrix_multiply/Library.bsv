import Vector::*;
import HaskellLib::*;
import Connectable::*;
import Base::*;
import Primitive::*;
export Library::*;

interface Empty_;
endinterface

interface Empty;
endinterface

module _Empty(Tuple2#(Empty_, Empty)) ;
  return tuple2(
    interface Empty_;
    endinterface,
    interface Empty;
    endinterface);
endmodule

instance Connectable#(Empty, Empty_) ;
  module mkConnection#(Empty a, Empty_ b)();
  endmodule
endinstance

instance Connectable#(Empty_, Empty) ;
  module mkConnection#(Empty_ a, Empty b)();
    mkConnection(asIfc(b), asIfc(a));
  endmodule
endinstance

typedef Bit#(TLog#(n)) Index#(type n);
typedef Bit#(TLog#(TAdd#(n, 1))) NumElems#(type n);

function Index#(n) moduloPlus(Integer size, NumElems#(n) incr, Index#(n) orig) provisos(Add#(a__, TLog#(n), TLog#(TAdd#(n, 1))));
  NumElems#(n) origLocal = zeroExtend(orig);
  NumElems#(n) retLocal = origLocal + incr <= (fromInteger(size - 1))?
    origLocal + incr: (origLocal + incr - fromInteger(size));
  return truncate(retLocal);
endfunction

