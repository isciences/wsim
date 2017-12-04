#include <Rcpp.h>
using namespace Rcpp;

#include "soil_moisture_change.h"
#include "precip_daily.h"

static inline double evapotranspiration(double P, double E0, double dWdt) {
  // Tech manual has P < E0, but Kepler has P <= E0
  // TODO make consistent
  if (P <= E0) {
    return P - dWdt;
  } else {
    return E0;
  }
}

// Runoff by Thornthwaite water balance equation
//
// @param P Effective precipication [L]
// @param E Evapotranspiration [L]
// @param dWdt Change in soil moisture [L]
// @return runoff [L]
static inline double runoff(double P, double E, double dWdt) {
	  return P - E - dWdt;
}

// Define a simple struct to return multiple parameters for each cell
// This is much faster than using Rcpp::List.
struct HydroVals {
  double dWdt;
  double Ws_ave;
  double E;
  double R;
};

static HydroVals daily_hydro_impl(double P, double Sa, double Sm, double E0, double Ws, double Wc, int nDays, double pWetDays) {
  double PET_daily = E0 / nDays;

  double dWdt = 0;
  double Ws_sum = 0;
  double E = 0;
  double R = 0;

  if (std::isnan(Sa)) {
    Sa = 0.0;
  }

  if (std::isnan(Sm)) {
    Sm = 0.0;
  }

  NumericVector rain_daily = make_daily_precip(P - Sa, nDays, pWetDays);
  NumericVector snowmelt_daily = make_daily_precip(Sm, nDays, 1.0);

  for (double P_daily : rain_daily + snowmelt_daily) {
    double dWdt_daily = soil_moisture_change(P_daily, PET_daily, Ws, Wc);

    Ws += dWdt_daily;
    Ws_sum += Ws;
    dWdt += dWdt_daily;

    double E_daily = std::max(0.0, evapotranspiration(P_daily, PET_daily, dWdt_daily));
    E += E_daily;

    double R_daily = std::max(0.0, runoff(P_daily, E_daily, dWdt_daily));
    R += R_daily;
  }


  HydroVals ret = {
    dWdt, Ws_sum / nDays, E, R
  };

  return ret;
}

//' Compute hydrological parameters over a multi-day timestep with precipitation on some days
//'
//' Precipitation is evenly divided over a set of evenly-spaced "wet days."
//' Snowmelt is evenly divided over the multi-day timestep.
//'
//' @param P  precipitation for the time step [L]
//' @param Sa snow accumulation for the time step [L]
//' @param Sm snow melt for the time step [L]
//' @param E0 potential evapotranspiration for the time step [L]
//' @param Ws soil moisture at start of time step [L]
//' @param Wc soil moisture holding capacity [L]
//' @param nDays number of days in time step [-]
//' @param pWetDays percentage of days with precipitation [-]
//' @return a List of hydrological parameters:
//'           dWdt:   change in soil moisture [L]
//'           Ws_ave: average soil moisture over timestep [L],
//'           E:      evapotranspiration [L]
//'           R:      runoff [L]
//'
//' @export
// [[Rcpp::export]]
List daily_hydro(double P, double Sa, double Sm, double E0, double Ws, double Wc, int nDays, double pWetDays) {
  HydroVals vals = daily_hydro_impl(P, Sa, Sm, E0, Ws, Wc, nDays, pWetDays);

  return List::create(
    Named("dWdt") = vals.dWdt,
    Named("Ws_ave") = vals.Ws_ave,
    Named("E") = vals.E,
    Named("R") = vals.R
  );
}

//' Compute hydrological parameters for all pixels
//'
//' @param P  precipitation for the time step [L]
//' @param Sa snow accumulation for the time step [L]
//' @param Sm snow melt for the time step [L]
//' @param E0 potential evapotranspiration for the time step [L]
//' @param Ws soil moisture at start of time step [L]
//' @param Wc soil moisture holding capacity [L]
//' @param nDays number of days in time step [-]
//' @param pWetDays percentage of days with precipitation [-]
//' @return a List of vectors of hydrological parameters:
//'           dWdt:   change in soil moisture [L]
//'           Ws_ave: average soil moisture over timestep [L],
//'           E:      evapotranspiration [L]
//'           R:      runoff [L]
//'
//' @export
// [[Rcpp::export]]
List daily_hydro_loop(const NumericMatrix & P,
                      const NumericMatrix & Sa,
                      const NumericMatrix & Sm,
                      const NumericMatrix & E0,
                      const NumericMatrix & Ws,
                      const NumericMatrix & Wc,
                      int nDays,
                      const NumericMatrix & pWetDays) {

  int rows = P.nrow();
  int cols = P.ncol();

  NumericMatrix dWdt = no_init(rows, cols);
  NumericMatrix Ws_ave = no_init(rows, cols);
  NumericMatrix E = no_init(rows, cols);
  NumericMatrix R = no_init(rows, cols);

  for (int j = 0; j < cols; j++) {
    for (int i = 0; i < rows; i++) {
      if (std::isnan(P(i, j)) || std::isnan(E0(i, j)) || std::isnan(Ws(i, j)) || std::isnan(Wc(i, j)) || std::isnan(pWetDays(i, j))) {
        dWdt(i, j) = NA_REAL;
        Ws_ave(i, j) = NA_REAL;
        E(i, j) = NA_REAL;
        R(i, j) = NA_REAL;
      } else {
        HydroVals hydro = daily_hydro_impl(P(i, j), Sa(i, j), Sm(i, j), E0(i, j), Ws(i, j), Wc(i, j), nDays, pWetDays(i, j));
        dWdt(i, j) = hydro.dWdt;
        Ws_ave(i, j) = hydro.Ws_ave;
        E(i, j) = hydro.E;
        R(i, j) = hydro.R;
      }
    }
  }

  return List::create(
    Named("dWdt") = dWdt,
    Named("Ws_ave") = Ws_ave,
    Named("E") = E,
    Named("R") = R
  );

}
