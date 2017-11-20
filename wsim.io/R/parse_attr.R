#' Parse a metadata attribute destined for a NetCDF file
#'
#' @param text representation of attribute
#' @param list representation of attribute
#' @export
parse_attr <- function(attr) {
  split_kv <- strsplit(attr, '=', fixed=TRUE)[[1]]
  key <- split_kv[1]
  val <- paste0(split_kv[-1])
  
  # If no val specified
  if (length(val) == 0) {
    val <- NULL
  }

  split_attr <- strsplit(key, ':', fixed=TRUE)[[1]]

  if (length(split_attr) == 1) {
    attr_var  <- NULL # global attribute
    attr_name <- key
  } else {
    attr_var <- split_attr[1]
    attr_name <- split_attr[2]
  }

  return(list(
    var=attr_var,
    key=attr_name,
    val=val
  ))
}
