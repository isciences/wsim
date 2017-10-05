#include <Rcpp.h>
using namespace Rcpp;

static double quagev(double f, double location, double scale, double shape) {
  if (shape == 0) {
    return location - scale*log(-log(f));
  }

  return location + scale/shape*(1 - pow(-log(f), shape));
}

static double cdfgev(double x, double location, double scale, double shape) {
  // Need to explicity check for NaN, because std::max(0, NaN) == 0
  if (std::isnan(x)) {
    return x;
  }

  double y = (x - location)/scale;
  if (shape != 0) {
    y = -1/shape*log(std::max(0.0, 1-shape*y));
  }

  return exp(-exp(-y));
}

//' @export
// [[Rcpp::export]]
NumericMatrix gev_quantiles(const NumericMatrix & data, const NumericMatrix & location, const NumericMatrix & scale, const NumericMatrix & shape) {
  int rows = data.nrow();
  int cols = data.ncol();

  NumericMatrix quantiles = no_init(rows, cols);

  for (int j = 0; j < cols; j++) {
    for (int i = 0; i < rows; i++) {
      quantiles(i, j) = cdfgev(data(i,j), location(i,j), scale(i,j), shape(i,j));
    }
  }

  return quantiles;
}

//' gev_correct
//'
//' Bias-correct a forecast using quantile-matching on computed distributions
//' of retrospective forecasts and observations.
//'
//' @param forecast A matrix representing forecast values
//' @param obs_location GEV location parameter from observed data
//' @param obs_scale GEV scale parameter from observed data
//' @param obs_shape GEV shape parameter from observed data
//' @param retro_location GEV location parameter from retrospective data
//' @param retro_scale GEV scale parameter from retrospective data
//' @param retro_shape GEV shape parameter from retrospective data
//'
//' @return a matrix with a corrected forecast
//'
//' @export
// [[Rcpp::export]]
NumericMatrix gev_correct(const NumericMatrix & data,
                          const NumericMatrix & obs_location,
                          const NumericMatrix & obs_scale,
                          const NumericMatrix & obs_shape,
                          const NumericMatrix & retro_location,
                          const NumericMatrix & retro_scale,
                          const NumericMatrix & retro_shape
) {
  int rows = data.nrow();
  int cols = data.ncol();

  NumericMatrix corrected = no_init(rows, cols);

  double extreme_cutoff = 100;
  double min_quantile = 1 / extreme_cutoff;
  double max_quantile = 1 - min_quantile;

  double when_dist_undefined = 0.5;

  for (int j = 0; j < cols; j++) {
    for (int i = 0; i < rows; i++) {
      if (std::isnan(data(i, j))) {
        corrected(i, j) = data(i, j);
      } else {
        double quantile;

        if (std::isnan(retro_location(i, j)) && std::isnan(retro_scale(i, j)) && std::isnan(retro_shape(i, j))) {
          quantile = when_dist_undefined;
        } else {
          quantile = cdfgev(data(i,j), retro_location(i, j), retro_scale(i,j), retro_shape(i,j));
        }

        quantile = std::min(quantile, max_quantile);
        quantile = std::max(quantile, min_quantile);

        corrected(i, j) = quagev(quantile, obs_location(i, j), obs_scale(i, j), obs_shape(i, j));
      }
    }
  }

  return corrected;
}
