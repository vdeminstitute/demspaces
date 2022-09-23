# h/t to @jimhester and @yihui for this parse block:
# https://github.com/yihui/knitr/blob/dc5ead7bcfc0ebd2789fe99c527c7d91afb3de4a/Makefile#L1-L4
# Note the portability change as suggested in the manual:
# https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Writing-portable-packages
PKGNAME = `sed -n "s/Package: *\([^ ]*\)/\1/p" demspaces/DESCRIPTION`
PKGVERS = `sed -n "s/Version: *\([^ ]*\)/\1/p" demspaces/DESCRIPTION`


all: check

build: install_deps
	R CMD build demspaces

check: build
	R CMD check --no-manual $(PKGNAME)_$(PKGVERS).tar.gz

install_deps:
	Rscript \
	-e 'if (!requireNamespace("remotes")) install.packages("remotes")' \
	-e 'remotes::install_deps("demspaces", dependencies = TRUE)'

install: build
	R CMD INSTALL $(PKGNAME)_$(PKGVERS).tar.gz

clean:
	@rm -rf $(PKGNAME)_$(PKGVERS).tar.gz $(PKGNAME).Rcheck


# Additions to the usethis::use_make template

docs:
	Rscript -e 'pkgdown::build_site("demspaces")'
.PHONY: docs

opendocs:
	open demspaces/docs/index.html
.PHONY: opendocs
