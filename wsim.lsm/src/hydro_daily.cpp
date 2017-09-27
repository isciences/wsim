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

    double E_daily = evapotranspiration(P_daily, PET_daily, dWdt_daily);
    E += E_daily;

    double R_daily = runoff(P_daily, E_daily, dWdt_daily);
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

  List ret;
  ret["dWdt"] = vals.dWdt;
  ret["Ws_ave"] = vals.Ws_ave;
  ret["E"] = vals.E;
  ret["R"] = vals.R;
  return ret;
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
List daily_hydro_loop(NumericVector P, NumericVector Sa, NumericVector Sm, NumericVector E0, NumericVector Ws, NumericVector Wc, int nDays, NumericVector pWetDays) {
  NumericVector dWdt(P.size());
  NumericVector Ws_ave(P.size());
  NumericVector E(P.size());
  NumericVector R(P.size());

  for (int i = 0; i < P.size(); i++) {
    if (std::isnan(P[i]) || std::isnan(E0[i]) || std::isnan(Ws[i]) || std::isnan(Wc[i]) || std::isnan(pWetDays[i])) {
      dWdt[i] = NA_REAL;
      Ws_ave[i] = NA_REAL;
      E[i] = NA_REAL;
      R[i] = NA_REAL;
    } else {
      HydroVals hydro = daily_hydro_impl(P[i], Sa[i], Sm[i], E0[i], Ws[i], Wc[i], nDays, pWetDays[i]);
      dWdt[i] = hydro.dWdt;
      Ws_ave[i] = hydro.Ws_ave;
      E[i] = hydro.E;
      R[i] = hydro.R;
    }
  }

  List ret;
  ret["dWdt"] = dWdt;
  ret["Ws_ave"] = Ws_ave;
  ret["E"] = E;
  ret["R"] = R;
  return ret;
}
