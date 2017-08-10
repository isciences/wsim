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

//' Runoff by Thornthwaite water balance equation
//'
//' @param P Effective precipication [L]
//' @param E Evapotranspiration [L]
//' @param dWdt Change in soil moisture [L]
//' @return runoff [L]
static inline double runoff(double P, double E, double dWdt) {
	  return P - E - dWdt;
}

//' @export
// [[Rcpp::export]]
List daily_hydro(double Pr, double Sm, double E0, double Ws, double Wc, int nDays, double pWetDays) {
  double PET_daily = E0 / nDays;

  double dWdt = 0;
  double E = 0;
  double R = 0;

  NumericVector Pr_daily = make_daily_precip(Pr - Sm, nDays, pWetDays);
  NumericVector Sm_daily = make_daily_precip(Sm, nDays, 1.0);

  for (double P_daily : Pr_daily + Sm_daily) {
    double dWdt_daily = soil_moisture_change(P_daily, PET_daily, Ws, Wc);

    Ws += dWdt_daily;
    dWdt += dWdt_daily;

    double E_daily = evapotranspiration(P_daily, PET_daily, dWdt_daily);
    E += E_daily;

    double R_daily = runoff(P_daily, E_daily, dWdt_daily);
    R += R_daily;
  }

  List ret;
  ret["dWdt"] = dWdt;
  ret["E"] = E;
  ret["R"] = R;
  return ret;
}

//' @export
// [[Rcpp::export]]
List daily_hydro_loop(NumericVector Pr, NumericVector Sm, NumericVector E0, NumericVector Ws, NumericVector Wc, int nDays, NumericVector pWetDays) {
  NumericVector dWdt(Pr.size());
  NumericVector E(Pr.size());
  NumericVector R(Pr.size());

  for (int i = 0; i < Pr.size(); i++) {
    if (isnan(Pr[i])|| isnan(Sm[i]) || isnan(E0[i]) || isnan(Ws[i]) || isnan(Wc[i]) || isnan(pWetDays[i])) {
      dWdt[i] = NA_REAL;
      E[i] = NA_REAL;
      R[i] = NA_REAL;
    } else {
      List hydro = daily_hydro(Pr[i], Sm[i], E0[i], Ws[i], Wc[i], nDays, pWetDays[i]);
      dWdt[i] = hydro["dWdt"];
      E[i] = hydro["E"];
      R[i] = hydro["R"];
    }
  }

  List ret;
  ret["dWdt"] = dWdt;
  ret["E"] = E;
  ret["R"] = R;
  return ret;
}

