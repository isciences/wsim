calc_Xr <- function(R, Pr, P) {
  ifelse(is.na(R) | is.na(Pr) | is.na(P) | P == 0, 0.0, R * Pr / P)
}

calc_Xs <- function(Sm, R, P) {
  ifelse(is.na(Sm) | is.na(R) | is.na(P) | P == 0, 0.0, Sm * R / P)
}

calc_Rp <- function(Dr, Xr) {
  0.5*(Dr + Xr)
}
