PAPER = fpga2015
TEX = $(wildcard *.tex)
BIB = references.bib
FIGS = $(wildcard figures/*.pdf figures/*.png graphs/*.pdf graphs/*.png)

.PHONY: all clean

$(PAPER).pdf: $(TEX) $(BIB) $(FIGS) jpaper.cls
	#echo $(FIGS)
	mkdir -p obj
	pdflatex -output-directory obj $(PAPER)
	cd obj; bibtex $(PAPER); cd ..;
	pdflatex -output-directory obj $(PAPER)
	pdflatex -output-directory obj $(PAPER)

clean:
	rm -rf obj

