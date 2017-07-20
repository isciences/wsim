#!/usr/bin/env bash
set -e

Rscript -e "devtools::document()"
Rscript -e "pkgdown::build_site()"

scp -r docs/* wsimop@192.168.100.84:/usr/share/nginx/html/wsim/wsim.distributions/
