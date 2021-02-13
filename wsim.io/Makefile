.PHONY: clean
clean:
	find ./ -name "*.so" | xargs rm
	find ./ -name "*.o" | xargs rm
	find ./ -name "RcppExports.*" | xargs rm

check:
	Rscript -e "results <- devtools::check(); stopifnot(length(results[['errors']]) == 0)"

install:
	Rscript -e "devtools::document(); devtools::install()"

html:
	Rscript -e "devtools::document(); pkgdown::build_site()"
