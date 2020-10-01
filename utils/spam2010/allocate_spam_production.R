#!/usr/bin/env Rscript

# Copyright (c) 2019 ISciences, LLC.
# All rights reserved.
#
# WSIM is licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License. You may
# obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

wsim.io::logging_init('allocate_spam_production')
suppressMessages({
  library(Rcpp)
  library(wsim.io)
  library(wsim.lsm)
  library(wsim.agriculture)
})

'
Standardize SPAM production data for use with WSIM.
Multiple SPAM crops will be combined into WSIM crops and then split into subcrops where applicable.

Usage: spam_allocate_production.R --spam_zip <file> --area_fractions <file> --method <m> --output <file>

Options:
--spam_zip <file>        ZIP file containing SPAM production data, e.g. spam2010v1r0_global_prod.geotiff.zip
--area_fractions <file>  File providing production fraction for each subcrop
--method <m>             Cultivation method (irrigated or rainfed)
--output <file>          Output file
'->usage

options(warn=2) # fail if expected files not found within zip

main <- function(raw_args) {
  args <- parse_args(usage, raw_args)  
  
  workdir <- tempdir()
  
  crops <- merge(wsim.agriculture::wsim_crops, 
                 wsim.agriculture::mirca_crops,
                 by='wsim_id')[, c('wsim_id', 'wsim_name', 'mirca_subcrops')]
  
  write_empty_results(args$output,
                      res=5/60,
                      crop_names=subcrop_names(crops$wsim_name, crops$mirca_subcrops),
                      vars=c('production'),
                      fill_zero=FALSE)
  
  for (i in seq_len(nrow(crops))) {
    crop_id <- crops[i, 'wsim_id']
    crop <- crops[i, 'wsim_name']
    n_subcrops <- crops[i, 'mirca_subcrops']
    
    infof('Preparing production data for %s', crop) 
    
    spam_abbrevs <- spam_crops[which(spam_crops$wsim_id == crop_id), 'spam_abbrev']
    
    spam_prod <- load_spam_production(args$spam_zip, spam_abbrevs, args$method) 
    
    if (n_subcrops > 1) {
      infof('Allocating production for %s among %d subcrops', crop, n_subcrops)
      for (subcrop in seq_len(n_subcrops)) {
        subcrop_name <- sprintf('%s_%d', crop, subcrop)
        area_frac <- read_vars_from_cdf(args$area_fractions, 
                                        vars = 'area_frac',
                                        extra_dims = list(crop=subcrop_name))$data[['area_frac']]
        
        subcrop_tot <- pprod(spam_prod, wsim.lsm::coalesce(area_frac, 0))
        
        infof('Writing production data for %s to %s', subcrop_name, args$output)
        write_vars_to_cdf(list(production=subcrop_tot),
                          args$output,
                          extent=c(-180, 180, -90, 90),
                          write_slice=list(crop=subcrop_name),
                          append=TRUE)
      }
    } else {
      infof('Writing production data for %s to %s', crop, args$output)
      write_vars_to_cdf(list(production=spam_prod),
                        args$output,
                        extent=c(-180, 180, -90, 90),
                        write_slice=list(crop=crop),
                        append=TRUE)
    }
  } 
}

if (!interactive()) {
  tryCatch(
    main(commandArgs(trailingOnly=TRUE))
  ,error=wsim.io::die_with_message)
}