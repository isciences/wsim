#' Get the command line string used to execute the current program
get_command <- function() {
  raw_args <- commandArgs(trailingOnly=FALSE)

  args <- as.character(c())
  cmd <- ''

  for (i in 1:length(raw_args)) {
    if (startsWith(raw_args[i], '--file=')) {
      cmd <- sub('--file=', '', raw_args[i], fixed=TRUE)
      break
    }
  }

  for (i in 1:length(raw_args)) {
    if (raw_args[i] == '--args') {
      args <- raw_args[-(1:i)]
      break
    }
  }

  return(paste(c(cmd, args), collapse=' '))
}
