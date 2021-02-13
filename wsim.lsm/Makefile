clean:
	rm ./*/RcppExport* || true
	rm NAMESPACE || true
	rm -r docs || true

check:
	Rscript -e "results <- devtools::check(); stopifnot(length(results[['errors']]) == 0)"

install:
	Rscript -e "pkgbuild::compile_dll(); devtools::document(); devtools::install()"

html:
	Rscript -e "pkgbuild::compile_dll(); devtools::document(); pkgdown::build_site()"
