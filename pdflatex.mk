# TARGET has to be specified

PDFLATEX_OPTIONS += -synctex=1
#LATEXMK     ?= latexmk -recorder -pdf -pdflatex="pdflatex $(PDFLATEX_OPTIONS) %O %S"
#LATEXMK     ?= latexmk -pdf -pdflatex="pdflatex $(PDFLATEX_OPTIONS) %O %S"
LATEXMK     ?= latexmk -pdf -e '$$pdflatex=q/pdflatex $(PDFLATEX_OPTIONS) %O %S/'

LATEXMK   ?= latexmk -pdf

PDFVIEWER ?= xdg-open
PDFLATEX  ?= pdflatex $(PDFLATEX_OPTIONS)               # Deprecated
BIBTEX    ?= bibtex                            # Deprecated

TEXCONFIG ?= config.tex


ifneq ($(strip $(TARGET)),)
PDFTARGETS  += $(TARGET).pdf
endif

# TeX include path
INCLUDEDIR = $(shell git rev-parse --show-toplevel)/common
export TEXINPUTS = $(INCLUDEDIR):

# Check for latexmk
LATEXMK_VERSION := $(shell latexmk --version 2> /dev/null)

export BOOKLET_SOURCE = $(PDFTARGETS)
export BOOKLET_TARGET_NAME = $(TARGET)-book
#=============================================================================

all: $(PDFTARGETS)

view: $(PDFTARGETS)
	$(PDFVIEWER) $(PDFTARGETS)


# Special compilation targets

default: | config-clear all
print: | config-print all

book-a5-booklet: | config-print config-book all

	echo "\documentclass{article} \
\usepackage[a4paper]{geometry} \
\usepackage[pdftex]{color,graphicx,epsfig} \
\usepackage{pdfpages} \
\begin{document} \
	\includepdf[pages=-,signature=12,landscape]{${BOOKLET_SOURCE}} \
\end{document}" > ${BOOKLET_TARGET_NAME}.tex

	pdflatex ${BOOKLET_TARGET_NAME}.tex

	rm -f ${BOOKLET_TARGET_NAME}.{tex,aux,log}


book-a5-signatures-4:
book-a5-signatures-8:
book-a5-signatures-12:
book-a5-signatures-16:



# Config write targets

config-print:
	echo "\keys_set:nn { mycourse } { style = default-print }" >> ${TEXCONFIG}
config-styledark:
	echo "\keys_set:nn { mycourse } { style = dark }" >> ${TEXCONFIG}
config-book:
	echo "\keys_set:nn { mycourse } { book }" >> ${TEXCONFIG}
config-a5:
	echo "\keys_set:nn { mycourse } { paper-size = a5 }" >> ${TEXCONFIG}
config-clear:
	echo "" > ${TEXCONFIG}


ifdef LATEXMK_VERSION
#================================
# Using latexmk
#--------------------------------
$(info latexmk installed.)


.PHONY: FORCE_MAKE

%.pdf: %.tex FORCE_MAKE
	$(LATEXMK) $<

#clean:
#	$(LATEXMK) -c $<
#
#distclean: clean
#	$(LATEXMK) -C



else
#================================
# Using pdflatex with make rules
#--------------------------------
$(info latexmk not installed, falling back to pdflatex make rules.)



# grep bibtex dependencies
ifneq ($(strip $(TARGET)),)
BIBFILES = $(patsubst %,%.bib,\
		$(shell grep '^[^%]*\\bibliography{' $(TARGET).tex | \
			sed -e 's/^[^%]*\\bibliography{\([^}]*\)}.*/\1/' \
			    -e 's/, */ /g'))
endif


#---------------------------------
# \input and \include dependencies
ifneq ($(strip $(TARGET)),)
INCLUDEDTEX := $(patsubst %,%.tex,\
		$(shell sed -rn 's/^[^%]*\\(input|include)\{([^\.\}]*)(\.tex)?\}/\2/p' $(TARGET).tex))
# second depth
ifneq ($(strip $(INCLUDEDTEX)),)
INCLUDEDTEX += $(foreach INCFILE,$(INCLUDEDTEX),$(patsubst %,%.tex,\
		$(shell sed -rn 's/^[^%]*\\(input|include)\{([^\.\}]*)(\.tex)?\}/\2/p' $(INCFILE))))
endif
endif
# quick-hack to get sty dependency (TODO: a clean solution)
INCLUDEDPKG = $(wildcard $(INCLUDEDIR)/*.sty) $(wildcard $(INCLUDEDIR)/*.cls)
#---------------------------------

AUXFILES = $(PDFTARGETS:.pdf=.aux)
AUXFILES += $(INCLUDEDTEX:.tex=.aux)
LOGFILES = $(AUXFILES:.aux=.log)

# short git revision
REVISION := $(shell git rev-parse --short HEAD)

.PHONY: all clean distclean pdf view

# to generate aux but not pdf from pdflatex, use -draftmode
.SECONDARY: $(AUXFILES)

$(AUXFILES): %.aux: | %.tex
	$(PDFLATEX) -draftmode $*;

# introduce BibTeX dependency if we found a \bibliography
ifneq ($(strip $(BIBFILES)),)
BIBDEPS = %.bbl
%.bbl: $(BIBFILES) %.aux
	$(BIBTEX) $*
endif

#$(PDFTARGETS): %.pdf: %.tex %.aux $(BIBDEPS) $(INCLUDEDTEX)
$(PDFTARGETS): %.pdf: %.tex $(INCLUDEDTEX) $(INCLUDEDPKG) | $(BIBDEPS)
	$(PDFLATEX) $*
ifneq ($(strip $(BIBFILES)),)
	@if grep -q "undefined references" $*.log; then \
		$(BIBTEX) $* && $(PDFLATEX) $*; fi
endif
	@while grep -q "Rerun to" $*.log; do \
		$(PDFLATEX) $*; done




endif # LATEXMK_VERSION


clean:
	rm -f $(foreach T,$(PDFTARGETS:.pdf=), \
		$(T).out $(T).thm $(T).blg $(T).bbl \
		$(T).lof $(T).lot $(T).toc $(T).idx \
		$(T).nav $(T).snm $(T)-pics.pdf \
		$(T).fdb_latexmk $(T).synctex.gz \
		$(T).log $(T).fls $(T).aux) \
		$(AUXFILES) $(LOGFILES)

distclean: clean
	rm -f $(PDFTARGETS)
