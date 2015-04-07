CONNECTALDIR=../../tools/connectal/

INTERFACES = FlashRequest FlashIndication

NUMBER_OF_MASTERS=1
PIN_TYPE=Top_Pins
DATA_BUS_WIDTH=128

#Note: for some reason, xbsv can't parase ControllerTypes.bsv properly. So a soft link in current directory is created
BSVFILES = Main.bsv Top.bsv \
	../../xilinx/aurora_8b10b_fmc1/AuroraImportFmc1.bsv \
	../../src/lib/AuroraCommon.bsv \
	../../controller/src/common/FlashBusModel.bsv \
	../../controller/src/model_virtex/FlashCtrlModel.bsv \
	../../controller/src/hw_virtex/FlashCtrlVirtex.bsv

CPPFILES=main.cpp

CONNECTALFLAGS = -D IMPORT_HOSTIF -D DataBusWidth=128 -D PinType=Top_Pins --clib rt --bscflags " -D DataBusWidth=128 -D PinType=Top_Pins"
#CONNECTALFLAGS=--bscflags " -D TRACE_AXI"


ifeq ($(BOARD), vc707)
CONNECTALFLAGS += \
	--verilog ../../xilinx/aurora_8b10b_fmc1/ \
	--verilog ../../xilinx/aurora_64b66b/ \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1.xci \
	--constraint ../../xilinx/aurora_8b10b_fmc1/aurora_8b10b_fmc1_exdes.xdc 

AURORA_INTRA = $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1_stub.v
prebuild:: $(AURORA_EXTRA) $(AURORA_INTRA)

$(AURORA_INTRA): ../../core-scripts/synth-aurora-intra.tcl
	(cd $(BOARD); vivado -mode batch -source ../../../core-scripts/synth-aurora-intra.tcl)

endif

include $(CONNECTALDIR)/Makefile.connectal
