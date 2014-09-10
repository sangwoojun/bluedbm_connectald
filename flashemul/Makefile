include ../config/Makefile.list

S2H = InterfaceRequest DmaConfig PlatformRequest
H2S = InterfaceIndication DmaIndication PlatformIndication
BSVFILES = Interface.bsv Top.bsv
CPPFILES=main.cpp rawWordManager.cpp
Dma = DmaF
PINS = Std

include ../config/Makefile.emultest
include ../config/Makefile.boardtest

XBSVDIR=../../xbsv
BOARD=vc707
TOP=$(PINS)Pcie$(Dma)Top
MKTOP=mkPcieTop

.PHONY: $(projectnames)
$(projectnames):
	$(XBSVDIR)/xbsvgen -B$(BOARD) -p $(BOARD) -x $(MKTOP) \
	$(foreach s2h, $(S2H), -s2h $(s2h)) \
	$(foreach h2s, $(H2S), -h2s $(h2s)) \
	$(foreach f, $(CPPFILES_ALL), -s $f) \
	-t $(TOP).bsv $(XBSVFLAGS) $(BSVFILES_ALL)

