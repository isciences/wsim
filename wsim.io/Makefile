check:
	Rscript -e "results <- devtools::check(); stopifnot(length(results[['errors']]) == 0)"

html:
	Rscript -e "devtools::document(); pkgdown::build_site()"
