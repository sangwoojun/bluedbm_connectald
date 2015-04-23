
import ControllerTypes::*;
import AuroraCommon::*;
import AuroraExtImport::*;

typedef struct {
	HeaderField srcNode;
	HeaderField dstNode;
	FlashCmd fcmd;
} FlashCmdRoute deriving (Bits, Eq);

typedef struct {
	HeaderField srcNode;
	HeaderField dstNode;
	BusT bus;
} TagEntry deriving (Bits, Eq);


typedef NUM_BUSES NUM_ENG_PORTS;
typedef TDiv#(NumTags, NUM_ENG_PORTS) TAGS_PER_PORT;

Integer num_eng_ports = valueOf(NUM_ENG_PORTS);
Integer tags_per_port = valueOf(TAGS_PER_PORT);
