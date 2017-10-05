#include <Rcpp.h>
using namespace Rcpp;

struct pe3_tag {};
struct gev_tag {};

template<typename T>
double qua(double x, double location, double scale, double shape);

template<>
double qua<pe3_tag>(double f, double location, double scale, double shape) {
  if (std::isnan(f)) {
    return f;
  } 
  
  if (shape < 1e-8) {
    return R::qnorm(f, location, scale, true, false);
  }
  
  double alpha = 4 / (shape*shape);
  double beta = abs(0.5*scale*shape);
  
  if (shape > 0) {
    return location - alpha*beta + beta*std::max(0.0, R::qgamma(f, alpha, 1, true, false));
  } else {
    return location + alpha*beta - beta*std::max(0.0, R::qgamma(1-f, alpha, 1, true, false));
  }
}

template<>
double qua<gev_tag>(double f, double location, double scale, double shape) {
  if (shape == 0) {
    return location - scale*log(-log(f));
  }

  return location + scale/shape*(1 - pow(-log(f), shape));
}

template<typename T>
double cdf(double x, double location, double scale, double shape);

template<>
double cdf<gev_tag>(double x, double location, double scale, double shape) {
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

template<>
double cdf<pe3_tag>(double x, double location, double scale, double shape) {
  if (std::isnan(x)) {
    return x;
  } 
  
  if (abs(shape) < 1e-6) {
    return R::pnorm(x, location, scale, true, false);
  }

  double alpha = 4/(shape*shape);
  double z = 2*(x - location) / (scale * shape) + alpha;

  double result = R::pgamma(std::max(0.0, z), alpha, 1, true, false);
  if (shape < 0) {
    result = 1 - result;
  }

  return result;
}
// [[Rcpp::export]]
double wsim_quape3(double x, double location, double scale, double shape) {
  return qua<pe3_tag>(x, location, scale, shape);  
}

// [[Rcpp::export]]
double wsim_quagev(double x, double location, double scale, double shape) {
  return qua<gev_tag>(x, location, scale, shape);  
}

// [[Rcpp::export]]
double wsim_cdfpe3(double x, double location, double scale, double shape) {
  return cdf<pe3_tag>(x, location, scale, shape);  
}

// [[Rcpp::export]]
double wsim_cdfgev(double x, double location, double scale, double shape) {
  return cdf<gev_tag>(x, location, scale, shape);  
}

//' @export
// [[Rcpp::export]]
NumericMatrix gev_quantiles(const NumericMatrix & data, const NumericMatrix & location, const NumericMatrix & scale, const NumericMatrix & shape) {
  int rows = data.nrow();
  int cols = data.ncol();

  NumericMatrix quantiles = no_init(rows, cols);

  for (int j = 0; j < cols; j++) {
    for (int i = 0; i < rows; i++) {
      quantiles(i, j) = cdf<gev_tag>(data(i,j), location(i,j), scale(i,j), shape(i,j));
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
          quantile = cdf<gev_tag>(data(i,j), retro_location(i, j), retro_scale(i,j), retro_shape(i,j));
        }

        quantile = std::min(quantile, max_quantile);
        quantile = std::max(quantile, min_quantile);

        corrected(i, j) = qua<gev_tag>(quantile, obs_location(i, j), obs_scale(i, j), obs_shape(i, j));
      }
    }
  }

  return corrected;
}
