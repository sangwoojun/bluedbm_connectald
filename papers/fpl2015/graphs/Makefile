TARGETS=latency.pdf bandwidth_hops.pdf bandwidth_links.pdf bandwidth_offset.pdf

%.ps: %.plot
	gnuplot $<
%.pdf: %.ps
	ps2pdf $<
	pdfcrop $@

all: $(TARGETS)
	mkdir -p obj
	mv *.ps obj
	mv *.pdf obj
