XBSVDIR=../../tools/xbsv/

S2H = FlashRequest
H2S = FlashIndication
BSVFILES = Main.bsv Top.bsv \
	../../xilinx/aurora_8b10b_fmc1/AuroraImportFmc1.bsv \
	../../xilinx/aurora_64b66b/AuroraExtImport.bsv \
	../../src/lib/AuroraCommon.bsv \
	../../src/lib/PageCache.bsv
CPPFILES=main.cpp
#XBSVFLAGS=--bscflags " -D TRACE_AXI"

EXTRA_XBSVFLAGS += -D IMPORT_HOSTIF -D PinType=Top_Pins --bscflags " -D DataBusWidth=128 " --clib rt


ifeq ($(BOARD), vc707)
EXTRA_XBSVFLAGS += \
	--verilog ../../xilinx/aurora_8b10b_fmc1/ \
	--verilog ../../xilinx/aurora_64b66b/ \
	--xci $(XBSVDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1.xci \
	--xci $(XBSVDIR)/out/$(BOARD)/aurora_64b66b_X1Y24/aurora_64b66b_X1Y24.xci \
	--xci $(XBSVDIR)/out/$(BOARD)/aurora_64b66b_X1Y25/aurora_64b66b_X1Y25.xci \
	--xci $(XBSVDIR)/out/$(BOARD)/aurora_64b66b_X1Y26/aurora_64b66b_X1Y26.xci \
	--xci $(XBSVDIR)/out/$(BOARD)/aurora_64b66b_X1Y27/aurora_64b66b_X1Y27.xci \
	--constraint ../../xilinx/aurora_64b66b/aurora_64b66b_exdes.xdc \
	--constraint ../../xilinx/aurora_8b10b_fmc1/aurora_8b10b_fmc1_exdes.xdc 


AURORA_INTRA = $(XBSVDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1_stub.v
AURORA_EXTRA = $(XBSVDIR)/out/$(BOARD)/aurora_64b66b_X1Y24/aurora_64b66b_X1Y24_stub.v
prebuild:: $(AURORA_INTRA) $(AURORA_EXTRA)

$(AURORA_INTRA): core-scripts/synth-aurora-intra.tcl
	(cd $(BOARD); vivado -mode batch -source ../core-scripts/synth-ip.tcl)
$(AURORA_EXTRA): core-scripts/synth-aurora-ext.tcl
	(cd $(BOARD); vivado -mode batch -source ../core-scripts/synth-aurora-ext.tcl)
	find $(XBSVDIR)/out/$(BOARD)/ -name "aurora_64b66b_X1Y??_wrapper.v" -exec sed -i "s/GT0_txdiffctrl_in[ \t]\+([4'b10]\+),/GT0_txdiffctrl_in (4'b1100),/g" '{}' \;
	
endif

include $(XBSVDIR)/Makefile.xbsv
