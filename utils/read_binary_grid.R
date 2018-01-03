#!/usr/bin/env Rscript
'
Reads monthly average temperature and precipitation from gridded files provided by NOAA

Usage: read_binary_grid (--input=<file> --var=<varname> --output_path=<path>) [--begin_date=<yyyymm> --skip_existing]

Options:
--input <file>         File to read
--var <varname>        Indicates whether [T]emperature or [P]recipitation should be read
--skip_existing        Indicates whether existing files should be skipped
--begin_date <yyyymm>  Start date of date in the file [default: 194801]
--output_path <path>   Folder in which outputs should be saved
'->usage

suppressMessages({
  require(wsim.io)
})

logging_init('read_binary_grid')

read_marker <- function(fh) {
  marker <- readBin(fh, 'integer', n=1, size=4, endian='big')
  if (length(marker) == 0) {
    return(NULL)
  }
  return(marker)
}

skip_binary_grid <- function(fh, nx, ny) {
  if (is.null(read_marker(fh))) {
    return(NULL)
  }

  seek(fh, where=4*ny*nx, origin='current')

  read_marker(fh)

  return(TRUE)
}

read_binary_grid <- function(fh, nx, ny, na_value=-999.0, flip_y=TRUE, rotate_x=TRUE) {
  if (is.null(read_marker(fh))) {
    return(NULL)
  }

  vals <- matrix(
    readBin(fh, 'numeric', n=ny*nx, size=4, endian='big'),
    nrow=ny,
    ncol=nx,
    byrow=TRUE)

  read_marker(fh)

  vals[vals == na_value] <- NA

  if (flip_y) {
    vals <- apply(vals, 2, rev)
  }

  if (rotate_x) {
    vals <- vals[ , c((nx/2+1):nx, 1:(nx/2))]
  }

  return(vals)
}


main <- function(raw_args) {
  args <- parse_args(usage, raw_args)

  year <- as.integer(substr(args$begin_date, 1, 4))
  month <- as.integer(substr(args$begin_date, 5, 6))

  infile <- file(args$input, 'rb')

  if (args$var == 'T') {
    attrs <- list(
      list(var='T', key='long_name', val='Temperature'),
      list(var='T', key='standard_name', val='surface_temperature'),
      list(var='T', key='units', val='degree_Celsius')
    )
  } else if (args$var == 'P') {
    attrs <- list(
      list(var='P', key='long_name', val='Precipitation'),
      list(var='P', key='standard_name', val='precipitation_amount'),
      list(var='P', key='units', val='mm')
    )
  } else {
    die_with_message("Unknown variable ", args$var)
  }

  while(1) {
      info('Processing', sprintf('%04d%02d', year, month))
      fname <- file.path(args$output_path,
                         sprintf('%s_%04d%02d.nc', args$var, year, month))

      if (file.exists(fname) && args$skip) {
        if(is.null(skip_binary_grid(infile, 720, 360))) {
          close(infile)
          break
        }
      } else {
        dat <- read_binary_grid(infile, 720, 360)

        if (is.null(dat)) {
          close(infile)
          break
        }

        to_write <- list()
        to_write[[args$var]] <- dat

        write_vars_to_cdf(to_write,
                          fname,
                          extent=c(-180, 180, -90, 90),
                          attrs=attrs)
      }

      month <- month + 1
      if (month > 12) {
        month <- 1
        year <- year + 1
      }
  }
}

if (!interactive()) {
  tryCatch(main(commandArgs(trailingOnly=TRUE)), error=die_with_message)
}
