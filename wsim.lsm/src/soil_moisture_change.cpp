// [[Rcpp::plugins(cpp11)]]
#include <Rcpp.h>
#include <cmath>
using namespace Rcpp;

// Define the two components of the unitless soil drying function.  Don't
// export these, so that we can define them as static inline
// (may help performance, not tested).
static inline double g1(double Ws, double Wc) {
  const double alpha = 5.0;
  static const double g1_denom = std::expm1(-alpha); // expm1(x) == exp(x)-1

  return std::expm1(-alpha * Ws / Wc) / g1_denom;
}

static inline double g2(double Ws, double E0, double P) {
  double beta = E0 / Ws;

  // TODO the formula below differs from the manual, but is what is implemented
  // in Kepler.  Manual has (E0-P), not (E0-P)/E0
  if (beta <= 1) {
    return E0 - P;
  } else {
    return Ws * std::expm1((P-E0) / Ws) / std::expm1(-beta);
  }
}

//' Unitless drying function
//' @param Ws Soil moisture (mm)
//' @param Wc Soil water holding capacity (mm)
//' @param E0 Potential evapotranspiration (mm/day)
//' @param P  Effective precipitation (mm/day)
//' @return   Magnitude of decline in soil moisture (mm/day)
//' @export
// [[Rcpp::export]]
double g(double Ws, double Wc, double E0, double P) {
  return g1(Ws, Wc) * g2(Ws, E0, P);
}

//' Change in soil moisture
//' @param P   Effective precipitation (mm/day)
//' @param E0  Potential evapotranspiration (mm/day)
//' @param Ws  Soil moisture (mm)
//' @param Wc  Soil moisture holding capacity (mm)
//'
//' @return    Change in soil moisture (mm/day)
//' @export
// [[Rcpp::export]]
double soil_moisture_change(double P, double E0, double Ws, double Wc)  {
  double Dws = (Wc - Ws) + E0;  // soil moisture deficit

  if (P <= E0) {
    // Precipitation is less than potential
    // evaporation, so we will experience
    // soil drying

    // TODO note that this does not match WSIM docs
    // but does appear to match Kepler
    // The docs would have us include the (E0 - P) term
    double dWdt = -g(Ws, Wc, E0, P); //* (E0 - P)

    // Prevent extreme drying in a single timestep.
    // This is taken from the Kepler workspace, but does not
    // appear in the technical manual.
    // TODO update manual
    return std::max(dWdt, -0.9*Ws);
  } else if  (P <= Dws) {
    // Precipitation is exceeds the potential evapotranspiration
    // demand, but is less than the soil moisture deficit.
    // Any precipitation not consumed by potential evapotranspiration
    // will be absorbed by the soil.
    return P - E0;
  } else {
    // Precipitation exceeds potential evapotranspiration and
    // the soil moisture deficit.  Fill the soil to capacity.
    return Wc - Ws;
  }
}
