#' Determine if a file can be opened for writing
#'
#' If the file exists, check if we have write
#' permissions on it.
#'
#' If the file does not exist, try creating a file
#' of that name, and then remove it.
#'
#' @param filename filename to test for write access
#' @return TRUE if the file can be opened for writing,
#'         FALSE otherwise
#' @export
can_write <- function(filename) {
  if (file.exists(filename)) {
    # File exists, can we write to it?
    return(unname(file.access(filename, mode=2)) == 0)
  } else {
    tryCatch({
      if(!file.create(filename, showWarnings=FALSE)) {
        return(FALSE)
      }
      while(!file.exists(filename)) {
        Sys.sleep(0.005)
      }
      file.remove(filename)
      return(TRUE);
    }, error=function() {
      return(FALSE);
    })
  }
}
