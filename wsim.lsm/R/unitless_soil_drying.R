g1.r <- function(Ws, Wc) {
  α = 5.0
  return ((1 - exp(-α * Ws / Wc)) / (1 - exp(-α)))
}

#cppFunction('
#            NumericVector g1(NumericVector Ws, NumericVector Wc) {
#            NumericVector out(Ws.size());
#            const double alpha = 5.0;
#            for (int i = 0; i < Ws.size(); i++) {
#            out[i] = (1 - exp(-alpha * Ws[i] / Wc[i])) / (1 - exp(-alpha));
#            }
#
#            return out;
#            };')
#
g2.r <- function(Ws, E0, P) {
  β <- E0 / Ws

  # TODO the formua below differs from the manual, but is what is implemented
  # in Kepler.  Manual has (E0-P), not (E0-P)/E0
  ifelse(β <= 1,
          E0 - P,
          Ws * (1 - exp(-β * (E0 - P) / E0)) / (1 - exp(-β)))
}

#cppFunction('
#            NumericVector g2(NumericVector Ws, NumericVector E0, NumericVector P) {
#            NumericVector beta = E0 / Ws;
#            NumericVector out(beta.size());
#
#            for(int i = 0; i < out.size(); i++) {
#            if (beta[i] <= 1) {
#            out[i] = E0[i] - P[i];
#            } else {
#            out[i] = Ws[i] * (1 - exp(-beta[i] * (E0[i] - P[i]))) / (1 - exp(-beta[i]));
#            }
#            }
#
#            return out;
#            }')

#' Unitless drying function
#' @param Ws Soil moisture (mm)
#' @param Wc Soil water holding capacity (mm)
#' @param E0 Potential evapotranspiration (mm/day)
#' @param P  Effective precipitation (mm/day)
#' @return   Magnitude of decline in soil moisture (mm/day)
g <- function(Ws, Wc, E0, P) {
  #cat('g1', g1.r(Ws, Wc), '\n')
  #cat('g2', g2.r(Ws, E0, P), '\n')
  g1.r(Ws, Wc) * g2.r(Ws, E0, P)
}
