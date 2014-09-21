XBSVDIR=../../tools/xbsv/

S2H = FlashRequest
H2S = FlashIndication
BSVFILES = Main.bsv Top.bsv \
	../../xilinx/aurora_8b10b_fmc1/AuroraImportFmc1.bsv \
	../../src/lib/PageCache.bsv
CPPFILES=main.cpp
#XBSVFLAGS=--bscflags " -D TRACE_AXI"

#EXTRA_XBSVFLAGS += -D IMPORT_HOSTIF -D PinType=Top_Pins
EXTRA_XBSVFLAGS += -D IMPORT_HOSTIF -D PinType=Top_Pins --bscflags " -D DataBusWidth=128 " --clib rt
ifeq ($(BOARD), vc707)
EXTRA_XBSVFLAGS += \
	--verilog ../../xilinx/aurora_8b10b_fmc1/ \
	--xci $(XBSVDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1.xci \
	--constraint ../../xilinx/aurora_8b10b_fmc1/aurora_8b10b_fmc1_exdes.xdc 


AURORA_V = $(XBSVDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1_stub.v
prebuild:: $(AURORA_V) 

$(AURORA_V): synth-ip.tcl
	(cd $(BOARD); vivado -mode batch -source ../synth-ip.tcl)
endif

include $(XBSVDIR)/Makefile.xbsv
