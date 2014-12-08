CONNECTALDIR=../../tools/connectal/

INTERFACES = StrstrRequestBDBM StrstrIndicationBDBM FlashRequest FlashIndication

#$(CONNECTALDIR)/lib/strstr/bsv/Strstr.bsv 
BSVFILES =  Top.bsv FlashTop.bsv StrstrBDBM.bsv \
			  	$(CONNECTALDIR)/lib/nandsim/bsv/NandSimNames.bsv \
				../../xilinx/aurora_8b10b_fmc1/AuroraImportFmc1.bsv \
				../../src/lib/AuroraCommon.bsv \
				../../controller/src/common/FlashBusModel.bsv \
				../../controller/src/model_virtex/FlashCtrlModel.bsv \
				../../controller/src/hw_virtex/FlashCtrlVirtex.bsv
#CPPFILES2=$(CONNECTALDIR)/examples/algo1_nandsim/test.cpp
CPPFILES= test.cpp
#CPPFILES=flashaccess.cpp
CONNECTALFLAGS += -D DEGPAR=4
#CONNECTALFLAGS += -I$(CONNECTALDIR)/lib/strstr/cpp


PIN_TYPE = Top_Pins
DATA_BUS_WIDTH=128
NUMBER_OF_MASTERS=1


CONNECTALFLAGS += -D IMPORT_HOSTIF -D DataBusWidth=128 -D PinType=Top_Pins --bscflags " -D DataBusWidth=128 -D PinType=Top_Pins" --clib rt


ifeq ($(BOARD), vc707)
CONNECTALFLAGS += \
	--verilog ../../xilinx/aurora_8b10b_fmc1/ \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1.xci \
	--constraint ../../xilinx/aurora_8b10b_fmc1/aurora_8b10b_fmc1_exdes.xdc 

AURORA_INTRA = $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1_stub.v
prebuild:: $(AURORA_INTRA)

$(AURORA_INTRA): core-scripts/synth-aurora-intra.tcl
	(cd $(BOARD); vivado -mode batch -source ../core-scripts/synth-aurora-intra.tcl)
endif

include $(CONNECTALDIR)/Makefile.connectal

