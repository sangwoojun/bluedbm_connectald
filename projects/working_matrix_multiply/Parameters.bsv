import Vector::*;
import HaskellLib::*;
import Connectable::*;
import Base::*;
import Primitive::*;
export Parameters::*;

typedef 512 NumPackets; 
typedef  8 NumBuses;   
typedef 128 PacketSz;   

typedef 1024 MaxBigI;
typedef 64 DataSz;






typedef 64 HostSz;
typedef 64 HostAddrSz;
typedef 64 BurstRespSz;

typedef TMul#(MaxBigI, NumPackets) MaxBigK;

import Library::*;
export Library::*;

typedef struct {
  NumElems#(MaxBigI) maxI;
  NumElems#(MaxBigI) maxK;
  NumElems#(MaxBigI) maxJ;
} Size deriving (Bits, Eq);


