
import ControllerTypes::*;

typedef struct {
	Bit#(6) srcNode;
	Bit#(6) dstNode;
	FlashCmd fcmd;
} FlashCmdRoute deriving (Bits, Eq);

typedef struct {
	Bit#(6) srcNode;
	Bit#(6) dstNode;
	BusT bus;
} TagEntry deriving (Bits, Eq);


typedef NUM_BUSES NUM_ENG_PORTS;
typedef TDiv#(NumTags, NUM_ENG_PORTS) TAGS_PER_PORT;

Integer num_eng_ports = valueOf(NUM_ENG_PORTS);
Integer tags_per_port = valueOf(TAGS_PER_PORT);
