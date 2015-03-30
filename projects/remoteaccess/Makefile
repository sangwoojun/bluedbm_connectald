CONNECTALDIR=../../tools/connectal

INTERFACES = GeneralRequest GeneralIndication

NUMBER_OF_MASTERS=1
PIN_TYPE=Top_Pins
DATA_BUS_WIDTH=128

BSVFILES = Main.bsv Top.bsv \
	../../xilinx/aurora_8b10b_fmc1/AuroraImportFmc1.bsv \
	../../xilinx/aurora_64b66b/AuroraExtDummy.bsv \
	../../src/lib/AuroraCommon.bsv \
	../../controller/src/common/FlashBusModel.bsv \
	../../controller/src/model_virtex/FlashCtrlModel.bsv \
	../../controller/src/hw_virtex/FlashCtrlVirtex.bsv

CPPFILES=main.cpp interface.cpp 

#CONNECTALFLAGS=--bscflags " -D TRACE_AXI"

CONNECTALFLAGS = -D IMPORT_HOSTIF -D DataBusWidth=128 -D PinType=Top_Pins --clib rt  --bscflags " -D DataBusWidth=128 -D PinType=Top_Pins"


ifeq ($(BOARD), vc707)
CONNECTALFLAGS += \
	--verilog ../../xilinx/aurora_64b66b/ \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y24/aurora_64b66b_X1Y24.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y25/aurora_64b66b_X1Y25.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y26/aurora_64b66b_X1Y26.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y27/aurora_64b66b_X1Y27.xci \
	-C ../../xilinx/aurora_64b66b/aurora_64b66b_exdes.xdc \
#	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y16/aurora_64b66b_X1Y16.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y17/aurora_64b66b_X1Y17.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y18/aurora_64b66b_X1Y18.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y19/aurora_64b66b_X1Y19.xci \

#AURORA_INTRA = $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1_stub.v
AURORA_EXTRA = $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y24/aurora_64b66b_X1Y24_stub.v
prebuild:: $(AURORA_EXTRA) $(AURORA_INTRA)

#$(AURORA_INTRA): ../../core-scripts/synth-aurora-intra.tcl
#	(cd $(BOARD); vivado -mode batch -source ../../../core-scripts/synth-aurora-intra.tcl)
#	find $(CONNECTALDIR)/out/$(BOARD)/ -name "aurora_8b10b_*transceiver_wrapper.v" -exec sed -i "s/_txdiffctrl_in[ \t]\+([4'b10]\+),/_txdiffctrl_in (4'b1011),/g" '{}' \;
$(AURORA_EXTRA): ../../core-scripts/synth-aurora-ext.tcl
	(cd $(BOARD); vivado -mode batch -source ../../../core-scripts/synth-aurora-ext.tcl)
	find $(CONNECTALDIR)/out/$(BOARD)/ -name "aurora_64b66b_X1Y??_wrapper.v" -exec sed -i "s/GT0_txdiffctrl_in[ \t]\+([4'b10]\+),/GT0_txdiffctrl_in (4'b1100),/g" '{}' \;
else
CONNECTALFLAGS += \
	--bsimsource ../../xilinx/aurora_64b66b/bdpi.cpp

endif 

include $(CONNECTALDIR)/Makefile.connectal
