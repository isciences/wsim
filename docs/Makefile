# Minimal makefile for Sphinx documentation
#

# You can set these variables from the command line.
SPHINXOPTS    =
SPHINXBUILD   = python3 -msphinx
SPHINXPROJ    = WSIM
SOURCEDIR     = .
BUILDDIR      = _build

# Put it first so that "make" without argument is like "make help".
help:
	@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

.PHONY: help Makefile

images:
	mkdir -p _generated
	cd _generated ; \
	for script in `find ../ -name "*.R"` ; do \
		echo $${script}; \
		Rscript $${script} || exit 1;\
	done \

_static/ol.css:
	wget -P _static https://cdnjs.cloudflare.com/ajax/libs/ol3/4.3.3/ol.css

_static/ol.js:
	wget -P _static https://cdnjs.cloudflare.com/ajax/libs/ol3/4.3.3/ol.js

js: _static/ol.css _static/ol.js
	

# Catch-all target: route all unknown targets to Sphinx using the new
# "make mode" option.  $(O) is meant as a shortcut for $(SPHINXOPTS).
%: Makefile images js
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)
