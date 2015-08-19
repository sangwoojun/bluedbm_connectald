CONNECTALDIR=../../tools/connectal/

CORE_SCRIPTS=$(shell realpath ../../core-scripts)

INTERFACES = FlashRequest FlashIndication StorageBridgeRequest StorageBridgeIndication
BSVFILES = Main.bsv Top.bsv \
	../../xilinx/aurora_8b10b_fmc1/AuroraImportFmc1.bsv \
	../../xilinx/aurora_64b66b/AuroraExtImport.bsv \
	../../src/lib/AuroraCommon.bsv \
	../../src/lib/PageCache.bsv
CPPFILES=main.cpp flashinterface.cpp storagebridge.cpp

PIN_TYPE=Top_Pins
CONNECTALFLAGS += -D DataBusWidth=128 -D IMPORT_HOSTIF --clib rt


ifeq ($(BOARD), vc707)
CONNECTALFLAGS += \
	--constraint ../../xilinx/ddr3_v2_0/vc707_ddr3_orig.xdc \
	--verilog ../../xilinx/ddr3_v2_0/ \
	--verilog ../../xilinx/aurora_8b10b_fmc1/ \
	--verilog ../../xilinx/aurora_64b66b/ \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y24/aurora_64b66b_X1Y24.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y25/aurora_64b66b_X1Y25.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y26/aurora_64b66b_X1Y26.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y27/aurora_64b66b_X1Y27.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y16/aurora_64b66b_X1Y16.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y17/aurora_64b66b_X1Y17.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y18/aurora_64b66b_X1Y18.xci \
	--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y19/aurora_64b66b_X1Y19.xci \
	--constraint ../../xilinx/aurora_64b66b/aurora_64b66b_exdes.xdc \
	--constraint ../../xilinx/aurora_8b10b_fmc1/aurora_8b10b_fmc1_exdes.xdc 

	#--verilog ../../../xbsv/xilinx/ddr3_v1_7/ \
	--constraint ../../xilinx/ddr3_v2_0/vc707_ddr3_sx.xdc \
	--constraint $(CONNECTALDIR)/xilinx/constraints/vc707_ddr3.xdc \
	--verilog $(BLUESPECDIR)/board_support/bluenoc/xilinx/VC707/verilog/ddr3_v2_0/ddr3_v2_0/user_design/rtl/ \
	--verilog $(BLUESPECDIR)/board_support/bluenoc/xilinx/VC707/verilog/ddr3_v2_0/ddr3_v2_0/user_design/rtl/clocking \
	--verilog $(BLUESPECDIR)/board_support/bluenoc/xilinx/VC707/verilog/ddr3_v2_0/ddr3_v2_0/user_design/rtl/controller \
	--verilog $(BLUESPECDIR)/board_support/bluenoc/xilinx/VC707/verilog/ddr3_v2_0/ddr3_v2_0/user_design/rtl/ecc \
	--verilog $(BLUESPECDIR)/board_support/bluenoc/xilinx/VC707/verilog/ddr3_v2_0/ddr3_v2_0/user_design/rtl/ip_top \
	--verilog $(BLUESPECDIR)/board_support/bluenoc/xilinx/VC707/verilog/ddr3_v2_0/ddr3_v2_0/user_design/rtl/phy \
	--verilog $(BLUESPECDIR)/board_support/bluenoc/xilinx/VC707/verilog/ddr3_v2_0/ddr3_v2_0/user_design/rtl/ui \

AURORA_INTRA = $(CONNECTALDIR)/out/$(BOARD)/aurora_8b10b_fmc1/aurora_8b10b_fmc1_stub.v
AURORA_EXTRA = $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y24/aurora_64b66b_X1Y24_stub.v
prebuild:: $(AURORA_INTRA) $(AURORA_EXTRA)

$(AURORA_INTRA):
	(cd $(BOARD); mkdir -p Cache; BUILDCACHE_CACHEDIR=Cache$(BUILDCACHE) vivado -mode batch -source $(CORE_SCRIPTS)/synth-aurora-intra.tcl)
$(AURORA_EXTRA):
	(cd $(BOARD); mkdir -p Cache; BUILDCACHE_CACHEDIR=Cache $(BUILDCACHE) vivado -mode batch -source $(CORE_SCRIPTS)/synth-aurora-ext.tcl)
	find $(CONNECTALDIR)/out/$(BOARD)/ -name "aurora_64b66b_X1Y??_wrapper.v" -exec sed -i "s/GT0_txdiffctrl_in[ \t]\+([4'b10]\+),/GT0_txdiffctrl_in (4'b1100),/g" '{}' \;
endif

include $(CONNECTALDIR)/Makefile.connectal
