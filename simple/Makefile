include ../config/Makefile.list

S2H = InterfaceRequest DmaConfig PlatformRequest
H2S = InterfaceIndication DmaIndication PlatformIndication
BSVFILES = Interface.bsv Top.bsv
CPPFILES=main.cpp
Dma = Dma
PINS = Std

include ../config/Makefile.emultest
include ../config/Makefile.boardtest
include ../config/Makefile.simple

XBSVDIR=../../xbsv
BOARD=bluesim
TOP=$(XBSVDIR)/bsv/BsimTop
#TOP=$(PINS)Pcie$(Dma)Top
MKTOP=mkBsimTop

.PHONY: $(projectnames)
$(projectnames):
	$(XBSVDIR)/xbsvgen -B$(BOARD) -p $(BOARD) -x $(MKTOP) \
	$(foreach s2h, $(S2H), -s2h $(s2h)) \
	$(foreach h2s, $(H2S), -h2s $(h2s)) \
	$(foreach f, $(CPPFILES_ALL), -s $f) \
	-t $(TOP).bsv $(XBSVFLAGS) $(BSVFILES_ALL)

