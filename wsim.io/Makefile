check:
	Rscript -e "results <- devtools::check(); stopifnot(length(results[['errors']]) == 0)"

install:
	Rscript -e "devtools::install()"

html:
	Rscript -e "devtools::document(); pkgdown::build_site()"
