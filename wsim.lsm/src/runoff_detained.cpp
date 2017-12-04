// [[Rcpp::plugins(cpp11)]]
#include <Rcpp.h>
using namespace Rcpp;

// [[Rcpp::export]]
double runoff_detained_snowpack_cpp(double Ds, double Xs, int melt_month, double z) {
  double f;

  // Propagate NA from melt_month and elevation
  if (melt_month == NA_INTEGER || std::isnan(z)) {
    return NA_REAL;
  }

  if (z < 500) {
    if (melt_month == 1) {
      f = 0.1;
    } else if (melt_month > 1) {
      f = 0.5;
    } else {
      f = 0.0;
    }
  } else {
    if (melt_month == 1) {
      f = 0.1;
    } else if (melt_month == 2) {
      f = 0.25;
    } else if (melt_month > 2) {
      f = 0.50;
    } else {
      f = 0.0;
    }
  }

  return f * (Ds + Xs);
}

//' Calculate detained runoff and snowmelt
//'
//' @param R runoff
//' @param Pr precipitation
//' @param P  net precipitation Pr - Sa + Sm
//' @param Sm snowmelt
//' @param Dr detained runoff
//' @param Ds detained snowmelt
//' @param z  elevation
//' @param melt_month number of consecutive
//'        months of melting conditions
// [[Rcpp::export]]
List calc_detained (const NumericVector & R,
                    const NumericVector & Pr,
                    const NumericVector & P,
                    const NumericVector & Sm,
                    const NumericVector & Dr,
                    const NumericVector & Ds,
                    const NumericVector & z,
                    const IntegerVector & melt_month) {
  NumericVector Rp = no_init(R.size());
  NumericVector Rs = no_init(R.size());
  NumericVector dDsdt = no_init(R.size());

  Rp.attr("dim") = R.attr("dim");
  Rs.attr("dim") = R.attr("dim");
  dDsdt.attr("dim") = R.attr("dim");

  for (int i = 0; i < R.size(); i++) {
    double Xr = 0;
    double Xs = 0;

    if (P[i] != 0) {
      Xr = R[i] * Pr[i] / P[i];
      Xs = R[i] * Sm[i] / P[i];

      if (std::isnan(Xr)) {
        Xr = 0.0;
      }
      if (std::isnan(Xs)) {
        Xs = 0.0;
      }
    }

    Rp[i] = 0.5*(Dr[i] + Xr);
    Rs[i] = runoff_detained_snowpack_cpp(Ds[i], Xs, melt_month[i], z[i]);

    dDsdt[i] = Xs - Rs[i];
  }

  return List::create(
    Named("dDsdt")=dDsdt,
    Named("Rp")=Rp,
    Named("Rs")=Rs
  );
}

