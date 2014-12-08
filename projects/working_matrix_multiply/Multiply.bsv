import Vector::*;
import HaskellLib::*;
import Connectable::*;
import Base::*;
import Primitive::*;
export Multiply::*;

import Parameters::*;
export Parameters::*;

import Fifo::*;
export Fifo::*;

typedef TDiv#(PacketSz, DataSz) NumDatas;
typedef TDiv#(DataSz, 2) HalfSz;
typedef Pair#(Bit#(HalfSz), Bit#(HalfSz)) RowCol;

interface PipeMult_;
  interface Output#(Pair#(Bit#(DataSz), Bit#(DataSz))) inp;
  interface Output_#(Bit#(DataSz)) outp;
endinterface

interface PipeMult;
  interface Output_#(Pair#(Bit#(DataSz), Bit#(DataSz))) inp;
  interface Output#(Bit#(DataSz)) outp;
endinterface

module _PipeMult(Tuple2#(PipeMult_, PipeMult)) ;
  Tuple2#(Output_#(Pair#(Bit#(DataSz), Bit#(DataSz))), Output#(Pair#(Bit#(DataSz), Bit#(DataSz)))) inp_ <- _Output(True, True);
  Tuple2#(Output_#(Bit#(DataSz)), Output#(Bit#(DataSz))) outp_ <- _Output(True, True);
  return tuple2(
    interface PipeMult_;
      interface inp = tpl_2(asIfc(inp_));
      interface outp = tpl_1(asIfc(outp_));
    endinterface,
    interface PipeMult;
      interface inp = tpl_1(asIfc(inp_));
      interface outp = tpl_2(asIfc(outp_));
    endinterface);
endmodule

instance Connectable#(PipeMult, PipeMult_) ;
  module mkConnection#(PipeMult a, PipeMult_ b)();
    mkConnection(asIfc(a.inp), asIfc(b.inp));
    mkConnection(asIfc(a.outp), asIfc(b.outp));
  endmodule
endinstance

instance Connectable#(PipeMult_, PipeMult) ;
  module mkConnection#(PipeMult_ a, PipeMult b)();
    mkConnection(asIfc(b), asIfc(a));
  endmodule
endinstance

typedef 6 MultPipeLen;

(* synthesize *)
module mkPipeMult(PipeMult) ;
  Tuple2#(PipeMult_, PipeMult) mod_ <- _PipeMult;

  Reg#(Vector#(4, Bit#(17))) x <- mkRegU;
  Reg#(Vector#(3, Bit#(24))) y <- mkRegU;

  Vector#(3, Vector#(4, Reg#(Bit#(41)))) out0 <- replicateM(replicateM(mkRegU));
  Vector#(3, Vector#(2, Reg#(Bit#(DataSz)))) out1 <- replicateM(replicateM(mkRegU));
  Vector#(3, Reg#(Bit#(DataSz))) out2 <- replicateM(mkRegU);
  Reg#(Bit#(DataSz)) out31 <- mkRegU;
  Reg#(Bit#(DataSz)) out32 <- mkRegU;
  Reg#(Bit#(DataSz)) out4 <- mkRegU;

  (* fire_when_enabled *) rule r;
    x <= unpack(zeroExtend((tpl_1(asIfc(mod_))).inp.fst));
    y <= unpack(zeroExtend((tpl_1(asIfc(mod_))).inp.snd));

    for(Integer j = 0; j < 3; j = j + 1)
      for(Integer i = 0; i < 4; i = i + 1)
      begin
        Bit#(41) v = pack(unsignedMul(unpack(x[i]), unpack(y[j])));
        out0[j][i] <= v;
      end

    for(Integer j = 0; j < 3; j = j + 1)
      for(Integer i = 0; i < 2; i = i + 1)
      begin
        Bit#(DataSz) v = (zeroExtend(out0[j][2*i]) << (17 * (2 * i))) + (zeroExtend(out0[j][2*i+1]) << (17 * (2 * i + 1)));
        out1[j][i] <= v;
      end

    for(Integer j = 0; j < 3; j = j + 1)
    begin
      out2[j] <= out1[j][0] + out1[j][1];
    end

    out31 <= out2[0] + (out2[1] << 24);
    out32 <= out2[2] << 48;

    out4 <= out31 + out32;

    (tpl_1(asIfc(mod_))).outp.write( truncate(out4));
  endrule

  return tpl_2(asIfc(mod_));
endmodule

interface PipeMultFull_;
  interface ConditionalOutput#(Pair#(Vector#(NumBuses, Bit#(PacketSz)), Bit#(PacketSz))) inp;
  interface ConditionalOutput_#(Vector#(NumBuses, Vector#(NumDatas, Bit#(DataSz)))) outp;
  interface Output_#(NumElems#(MultPipeLen)) numElems;
endinterface

interface PipeMultFull;
  interface ConditionalOutput_#(Pair#(Vector#(NumBuses, Bit#(PacketSz)), Bit#(PacketSz))) inp;
  interface ConditionalOutput#(Vector#(NumBuses, Vector#(NumDatas, Bit#(DataSz)))) outp;
  interface Output#(NumElems#(MultPipeLen)) numElems;
endinterface

module _PipeMultFull(Tuple2#(PipeMultFull_, PipeMultFull)) ;
  Tuple2#(ConditionalOutput_#(Pair#(Vector#(NumBuses, Bit#(PacketSz)), Bit#(PacketSz))), ConditionalOutput#(Pair#(Vector#(NumBuses, Bit#(PacketSz)), Bit#(PacketSz)))) inp_ <- _ConditionalOutput(True, True);
  Tuple2#(ConditionalOutput_#(Vector#(NumBuses, Vector#(NumDatas, Bit#(DataSz)))), ConditionalOutput#(Vector#(NumBuses, Vector#(NumDatas, Bit#(DataSz))))) outp_ <- _ConditionalOutput(True, True);
  Tuple2#(Output_#(NumElems#(MultPipeLen)), Output#(NumElems#(MultPipeLen))) numElems_ <- _Output(True, True);
  return tuple2(
    interface PipeMultFull_;
      interface inp = tpl_2(asIfc(inp_));
      interface outp = tpl_1(asIfc(outp_));
      interface numElems = tpl_1(asIfc(numElems_));
    endinterface,
    interface PipeMultFull;
      interface inp = tpl_1(asIfc(inp_));
      interface outp = tpl_2(asIfc(outp_));
      interface numElems = tpl_2(asIfc(numElems_));
    endinterface);
endmodule

instance Connectable#(PipeMultFull, PipeMultFull_) ;
  module mkConnection#(PipeMultFull a, PipeMultFull_ b)();
    mkConnection(asIfc(a.inp), asIfc(b.inp));
    mkConnection(asIfc(a.outp), asIfc(b.outp));
    mkConnection(asIfc(a.numElems), asIfc(b.numElems));
  endmodule
endinstance

instance Connectable#(PipeMultFull_, PipeMultFull) ;
  module mkConnection#(PipeMultFull_ a, PipeMultFull b)();
    mkConnection(asIfc(b), asIfc(a));
  endmodule
endinstance

(* synthesize *)
module mkPipeMultFull(PipeMultFull) ;
  Tuple2#(PipeMultFull_, PipeMultFull) mod_ <- _PipeMultFull;

  Vector#(MultPipeLen, Reg#(Bool)) outValids <- replicateM(mkReg(False));
  Vector#(NumBuses, Vector#(NumDatas, PipeMult)) mults <- replicateM(replicateM(mkPipeMult));

  (* fire_when_enabled *) rule r;
    for(Integer i = 1; i < valueOf(MultPipeLen); i=i+1)
      outValids[i] <= outValids[i-1];
    outValids[0] <= (tpl_1(asIfc(mod_))).inp.en;

    for(Integer i = 0; i < valueOf(NumBuses); i=i+1)
    begin
      Vector#(NumBuses, Vector#(NumDatas, Bit#(DataSz))) a = unpack(pack((tpl_1(asIfc(mod_))).inp.fst));
      Vector#(NumDatas, Bit#(DataSz)) b = unpack((tpl_1(asIfc(mod_))).inp.snd);
      for(Integer j = 0; j < valueOf(NumDatas); j=j+1)
      begin
        mults[i][j].inp.write( Pair{fst: a[i][j], snd: b[j]});
      end
    end

    Vector#(NumBuses, Vector#(NumDatas, Bit#(DataSz))) outval = replicate(newVector);
    for(Integer i = 0; i < valueOf(NumBuses); i=i+1)
      for(Integer j = 0; j < valueOf(NumDatas); j=j+1)
      begin
        outval[i][j] = mults[i][j].outp;
      end
    if(outValids[valueOf(MultPipeLen)-1])
      (tpl_1(asIfc(mod_))).outp.write( outval);

    Vector#(MultPipeLen, Bool) outvals = newVector;
    for(Integer i = 0; i < valueOf(MultPipeLen); i=i+1)
      outvals[i] = outValids[i];
    (tpl_1(asIfc(mod_))).numElems.write( pack(countOnes(pack(outvals))));
  endrule

  return tpl_2(asIfc(mod_));
endmodule

interface Multiply_;
  interface UgFifoEnq#(Pair#(Vector#(NumBuses, Bit#(PacketSz)), Bit#(PacketSz))) toMult;
  interface UgFifoDeq#(Vector#(NumBuses, Bit#(DataSz))) fromMult;
endinterface

interface Multiply;
  interface UgFifoEnq_#(Pair#(Vector#(NumBuses, Bit#(PacketSz)), Bit#(PacketSz))) toMult;
  interface UgFifoDeq_#(Vector#(NumBuses, Bit#(DataSz))) fromMult;
endinterface

module _Multiply(Tuple2#(Multiply_, Multiply)) ;
  Tuple2#(UgFifoEnq_#(Pair#(Vector#(NumBuses, Bit#(PacketSz)), Bit#(PacketSz))), UgFifoEnq#(Pair#(Vector#(NumBuses, Bit#(PacketSz)), Bit#(PacketSz)))) toMult_ <- _UgFifoEnq;
  Tuple2#(UgFifoDeq_#(Vector#(NumBuses, Bit#(DataSz))), UgFifoDeq#(Vector#(NumBuses, Bit#(DataSz)))) fromMult_ <- _UgFifoDeq;
  return tuple2(
    interface Multiply_;
      interface toMult = tpl_2(asIfc(toMult_));
      interface fromMult = tpl_2(asIfc(fromMult_));
    endinterface,
    interface Multiply;
      interface toMult = tpl_1(asIfc(toMult_));
      interface fromMult = tpl_1(asIfc(fromMult_));
    endinterface);
endmodule

instance Connectable#(Multiply, Multiply_) ;
  module mkConnection#(Multiply a, Multiply_ b)();
    mkConnection(asIfc(a.toMult), asIfc(b.toMult));
    mkConnection(asIfc(a.fromMult), asIfc(b.fromMult));
  endmodule
endinstance

instance Connectable#(Multiply_, Multiply) ;
  module mkConnection#(Multiply_ a, Multiply b)();
    mkConnection(asIfc(b), asIfc(a));
  endmodule
endinstance

typedef TAdd#(1, MultPipeLen) MidFifoSize;

(* synthesize *)
module mkMultiply(Multiply) ;
  Tuple2#(Multiply_, Multiply) mod_ <- _Multiply;

  UgFifo#(2, Pair#(Vector#(NumBuses, Bit#(PacketSz)), Bit#(PacketSz))) inQ <- mkUgFifo;
  UgFifo#(2, Vector#(NumBuses, Bit#(DataSz))) outQ <- mkUgFifo;
  function Bit#(x) myAdd(Bit#(x) a, Bit#(x) b) = a + b;

  UgFifo#(MidFifoSize, Vector#(NumBuses, Vector#(NumDatas, Bit#(DataSz)))) middleQ <- mkUgFifo;

  PipeMultFull mult <- mkPipeMultFull;

  
                                                     
                
                                                                      
                                                                                  
                                                    
         
                                                                            
                                                      
                                         
       
                           
           
  

  (* fire_when_enabled *) rule r01(inQ.deq.notEmpty && middleQ.numFilled + mult.numElems < fromInteger(valueOf(MidFifoSize)));
    mult.inp.write( inQ.deq.first);
    
    
    inQ.deq.deq;
  endrule

  (* fire_when_enabled *) rule r02(mult.outp.en);
  
                                
                                                    
                                                      
                                       
                 
  
    middleQ.enq.enq.write( mult.outp);
  endrule

  (* fire_when_enabled *) rule r1(middleQ.deq.notEmpty && outQ.enq.notFull);
    middleQ.deq.deq;
    Vector#(NumBuses, Bit#(DataSz)) ret = newVector;
    for(Integer x = 0; x < valueOf(NumBuses); x=x+1)
      ret[x] = fold(myAdd, middleQ.deq.first[x]);

    outQ.enq.enq.write( ret);
  endrule

  
                                                 
                
                                
                                                    
         
                                                                       
                                                      
                                                           
       
                  
                                                                  
                                                    
                                                         
                 

                                                                             
           
  

  mkConnection(asIfc(inQ.enq), asIfc( (tpl_1(asIfc(mod_))).toMult));
  mkConnection(asIfc(outQ.deq), asIfc( (tpl_1(asIfc(mod_))).fromMult));

  return tpl_2(asIfc(mod_));
endmodule

