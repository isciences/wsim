#' Parse a metadata attribute destined for a NetCDF file
#'
#' @param attr text representation of attribute in the
#'             following format:
#'
#'             var_name:attr_name=attr_val
#'
#'             If no var_name is specified, the attribute
#'             will be interpreted to be a global attribute.
#'
#'             If no attr_val is specified, it will be set
#'             to NULL in the returned list.
#'
#' @return a list representation of attribute, with items
#'         var, key, and val corresponding to var_name, attr_name,
#'         and attr_val
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
