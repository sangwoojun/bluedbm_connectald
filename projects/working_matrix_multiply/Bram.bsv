import Vector::*;
import HaskellLib::*;
import Connectable::*;
import Base::*;
import Primitive::*;
export Bram::*;

import Library::*;
export Library::*;

import RegsFile::*;
export RegsFile::*;

import BramVerilog::*;

typedef RegFile Bram;
typedef RegFile_ Bram_;

module mkBramSingle(Bram#(1, 1, size, t)) provisos(Bits#(t, tSz));
  Tuple2#(Bram_#(1, 1, size, t), Bram#(1, 1, size, t)) mod_ <- _RegFile;

  BramVerilog_#(size, t) bram <- mkBramVerilog;

  (* fire_when_enabled *) rule a;
    bram.readReq((tpl_1(asIfc(mod_))).read[0].req);
    (tpl_1(asIfc(mod_))).read[0].resp.write( bram.readResp);
    if((tpl_1(asIfc(mod_))).write[0].en)
      bram.write((tpl_1(asIfc(mod_))).write[0].fst, (tpl_1(asIfc(mod_))).write[0].snd);
  endrule

  return tpl_2(asIfc(mod_));
endmodule


module mkBramU(Bram#(reads, writes, size, t))provisos(Bits#(t, tSz));
  Bram#(reads, writes, size, t) mod_ <- mkMultiplePorts(mkBramSingle);
  return mod_;
endmodule

