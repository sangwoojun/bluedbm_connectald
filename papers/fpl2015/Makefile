PAPER = fpl2015 
TEX = $(wildcard *.tex)
BIB = $(wildcard *.bib) 
FIGS = $(wildcard figures/*.pdf figures/*.png graphs/*.pdf graphs/*.png)

.PHONY: all clean

$(PAPER).pdf: $(TEX) $(BIB) $(FIGS) IEEEtran.cls
	#echo $(FIGS)
	mkdir -p obj
	pdflatex -output-directory obj $(PAPER)
	pdflatex -output-directory obj $(PAPER)
	cp *.bib obj/
	cd obj; bibtex $(PAPER); cd ..;
	pdflatex -output-directory obj $(PAPER)
	pdflatex -output-directory obj $(PAPER)

clean:
	rm -rf obj


