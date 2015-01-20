import Vector::*;
import HaskellLib::*;
import Connectable::*;
import Base::*;
import Primitive::*;
export Receiver::*;

import Library::*;
export Library::*;

import Fifo::*;
export Fifo::*;

import Parameters::*;
export Parameters::*;

(* synthesize *)

module mkBramFifoRecv(UgFifo#(NumPackets, Bit#(PacketSz)));
  UgFifo#(NumPackets, Bit#(PacketSz)) mod_ <- mkBramFifo;
  return mod_;
endmodule

interface Receiver_;
  interface Output_#(Bool) busy;
  interface ConditionalOutput#(Size) setSize;
  interface ConditionalOutput_#(Pair#(Pair#(Bit#(1), Index#(NumBuses)), Pair#(Index#(MaxBigI), Index#(MaxBigI)))) dataReq;
  interface Vector#(2, Vector#(NumBuses, ConditionalOutput#(Bit#(PacketSz)))) dataResp;
  interface UgFifoEnq_#(Pair#(Vector#(NumBuses, Bit#(PacketSz)), Bit#(PacketSz))) toMult;
  interface ConditionalOutput_#(Size) recvInd;
endinterface

interface Receiver;
  interface Output#(Bool) busy;
  interface ConditionalOutput_#(Size) setSize;
  interface ConditionalOutput#(Pair#(Pair#(Bit#(1), Index#(NumBuses)), Pair#(Index#(MaxBigI), Index#(MaxBigI)))) dataReq;
  interface Vector#(2, Vector#(NumBuses, ConditionalOutput_#(Bit#(PacketSz)))) dataResp;
  interface UgFifoEnq#(Pair#(Vector#(NumBuses, Bit#(PacketSz)), Bit#(PacketSz))) toMult;
  interface ConditionalOutput#(Size) recvInd;
endinterface

module _Receiver(Tuple2#(Receiver_, Receiver)) ;
  Tuple2#(Output_#(Bool), Output#(Bool)) busy_ <- _Output(True, True);
  Tuple2#(ConditionalOutput_#(Size), ConditionalOutput#(Size)) setSize_ <- _ConditionalOutput(True, True);
  Tuple2#(ConditionalOutput_#(Pair#(Pair#(Bit#(1), Index#(NumBuses)), Pair#(Index#(MaxBigI), Index#(MaxBigI)))), ConditionalOutput#(Pair#(Pair#(Bit#(1), Index#(NumBuses)), Pair#(Index#(MaxBigI), Index#(MaxBigI))))) dataReq_ <- _ConditionalOutput(True, True);
  Tuple2#(Vector#(2, Vector#(NumBuses, ConditionalOutput_#(Bit#(PacketSz)))), Vector#(2, Vector#(NumBuses, ConditionalOutput#(Bit#(PacketSz))))) dataResp_ <- replicateTupleM(replicateTupleM(_ConditionalOutput(True, True)));
  Tuple2#(UgFifoEnq_#(Pair#(Vector#(NumBuses, Bit#(PacketSz)), Bit#(PacketSz))), UgFifoEnq#(Pair#(Vector#(NumBuses, Bit#(PacketSz)), Bit#(PacketSz)))) toMult_ <- _UgFifoEnq;
  Tuple2#(ConditionalOutput_#(Size), ConditionalOutput#(Size)) recvInd_ <- _ConditionalOutput(True, True);
  return tuple2(
    interface Receiver_;
      interface busy = tpl_1(asIfc(busy_));
      interface setSize = tpl_2(asIfc(setSize_));
      interface dataReq = tpl_1(asIfc(dataReq_));
      interface dataResp = tpl_2(asIfc(dataResp_));
      interface toMult = tpl_1(asIfc(toMult_));
      interface recvInd = tpl_1(asIfc(recvInd_));
    endinterface,
    interface Receiver;
      interface busy = tpl_2(asIfc(busy_));
      interface setSize = tpl_1(asIfc(setSize_));
      interface dataReq = tpl_2(asIfc(dataReq_));
      interface dataResp = tpl_1(asIfc(dataResp_));
      interface toMult = tpl_2(asIfc(toMult_));
      interface recvInd = tpl_2(asIfc(recvInd_));
    endinterface);
endmodule

instance Connectable#(Receiver, Receiver_) ;
  module mkConnection#(Receiver a, Receiver_ b)();
    mkConnection(asIfc(a.busy), asIfc(b.busy));
    mkConnection(asIfc(a.setSize), asIfc(b.setSize));
    mkConnection(asIfc(a.dataReq), asIfc(b.dataReq));
    mkConnection(asIfc(a.dataResp), asIfc(b.dataResp));
    mkConnection(asIfc(a.toMult), asIfc(b.toMult));
    mkConnection(asIfc(a.recvInd), asIfc(b.recvInd));
  endmodule
endinstance

instance Connectable#(Receiver_, Receiver) ;
  module mkConnection#(Receiver_ a, Receiver b)();
    mkConnection(asIfc(b), asIfc(a));
  endmodule
endinstance

(* synthesize *)
module mkReceiver(Receiver) ;
  Tuple2#(Receiver_, Receiver) mod_ <- _Receiver;

  Vector#(2, Vector#(NumBuses, UgFifo#(NumPackets, Bit#(PacketSz)))) matrix <-
    replicateM(replicateM(mkBramFifoRecv));

  Reg#(Bool) busyReg <- mkReg(False);

  Reg#(Index#(MaxBigI)) bigI <- mkReg(0);
  Reg#(Index#(MaxBigI)) bigK <- mkReg(0);
  Reg#(Index#(MaxBigI)) bigJ <- mkReg(0);

  Reg#(NumElems#(NumBuses)) i <- mkReg(0);
  Reg#(NumElems#(NumBuses)) j <- mkReg(0);
  Reg#(NumElems#(NumPackets)) k <- mkReg(0);
  Reg#(NumElems#(NumBuses)) jComp <- mkReg(0);

  Reg#(NumElems#(MaxBigI)) maxI <- mkRegU;
  Reg#(NumElems#(MaxBigI)) maxK <- mkRegU;
  Reg#(NumElems#(MaxBigI)) maxJ <- mkRegU;

  (* fire_when_enabled *) rule r0;
    (tpl_1(asIfc(mod_))).busy.write( busyReg);
  endrule

  (* fire_when_enabled *) rule init(!busyReg && (tpl_1(asIfc(mod_))).setSize.en);
    maxI <= (tpl_1(asIfc(mod_))).setSize.maxI;
    maxJ <= (tpl_1(asIfc(mod_))).setSize.maxJ;
    maxK <= (tpl_1(asIfc(mod_))).setSize.maxK;
    bigI <= 0;
    bigK <= 0;
    bigJ <= 0;
    i <= 0;
    k <= 0;
    j <= 0;

    busyReg <= True;
  endrule

  (* fire_when_enabled *) rule sendReqA(busyReg && i < fromInteger(valueOf(NumBuses)));
    Index#(NumBuses) iT = truncate(i);
    (tpl_1(asIfc(mod_))).dataReq.write( Pair{fst: Pair{fst:0, snd: iT}, snd: Pair{fst: truncate(bigI), snd: truncate(bigK)}});
    i <= i + 1;
  endrule

  (* fire_when_enabled *) rule sendReqB(busyReg && i == fromInteger(valueOf(NumBuses)) && j < fromInteger(valueOf(NumBuses)));
    Index#(NumBuses) jT = truncate(j);
    (tpl_1(asIfc(mod_))).dataReq.write( Pair{fst: Pair{fst:1, snd: jT}, snd: Pair{fst: truncate(bigJ), snd: truncate(bigK)}});
    j <= j + 1;
  endrule

  for(Integer w = 0; w < fromInteger(2); w=w+1)
  begin
    for(Integer x = 0; x < fromInteger(valueOf(NumBuses)); x=x+1)
    begin
      (* fire_when_enabled *) rule getResp((tpl_1(asIfc(mod_))).dataResp[w][x].en);
        $display("%d Receiver flash response %d %d", $time, w, x);
        matrix[w][x].enq.enq.write( (tpl_1(asIfc(mod_))).dataResp[w][x]);
      endrule
    end
  end

  (* fire_when_enabled *) rule sendCompute(busyReg && jComp < fromInteger(valueOf(NumBuses)) &&
                     (tpl_1(asIfc(mod_))).toMult.notFull && matrix[1][jComp].deq.notEmpty);
    let bVal = matrix[1][jComp].deq.first;
    $display("%d Receiver Doing work with %d", $time, jComp);
    Vector#(NumBuses, Bit#(PacketSz)) aVals = newVector;
    for(Integer x = 0; x < fromInteger(valueOf(NumBuses)); x=x+1)
      aVals[x] = matrix[0][x].deq.first;
    (tpl_1(asIfc(mod_))).toMult.enq.write( Pair{fst: aVals, snd: bVal});
    jComp <= jComp + 1;
  endrule

  (* fire_when_enabled *) rule computeNextBRow(busyReg && i == fromInteger(valueOf(NumBuses)) && j == fromInteger(valueOf(NumBuses)) &&
                                    jComp == fromInteger(valueOf(NumBuses)));
    for(Integer x = 0; x < fromInteger(valueOf(NumBuses)); x=x+1)
    begin
      matrix[0][x].deq.deq;
      matrix[1][x].deq.deq;
    end
    $display("%d Receiver dequeuing packet %d", $time, k);
    jComp <= 0;
    if(k == fromInteger(valueOf(NumPackets))-1)
    begin
      k <= 0;
  
      i <= 0;
      j <= 0;
      (tpl_1(asIfc(mod_))).recvInd.write( Size{maxI: zeroExtend(bigI), maxJ: zeroExtend(bigJ), maxK: zeroExtend(bigK)});
      $display("%d Receiver", $time);
  
      if(zeroExtend(bigK) == maxK - 1)
      begin
        bigK <= 0;
        if(zeroExtend(bigJ) == maxJ - 1)
        begin
          bigI <= bigI + 1;
          bigJ <= 0;
          if(zeroExtend(bigI) == maxI - 1)
          begin
            $display("%d Receiver Everything done", $time);
            busyReg <= False;
          end
        end
        else
          bigJ <= bigJ + 1;
      end
      else
        bigK <= bigK + 1;
    end
    else
      k <= k + 1;
  endrule

  
                                                                                                                     
                                                                 
         
                           
                           
       
                                                          
               
               
           

                                   
                                                               
                                                               
                                      
                                                                

                                                                 
         
                         
                         
       

           

           
           
                                                                                            
                                   

                                    
         
                
                                      
           
                         
                  
                                        
             
                                                         
                           
           
         
          
                         
       
        
                       
           
  

  return tpl_2(asIfc(mod_));
endmodule

