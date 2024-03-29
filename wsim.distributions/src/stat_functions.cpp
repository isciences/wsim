// Copyright (c) 2018-2019 ISciences, LLC.
// All rights reserved.
//
// WSIM is licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License. You may
// obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// [[Rcpp::plugins(cpp11)]]
#include <Rcpp.h>
using namespace Rcpp;

// Define supported distributions
struct pe3_tag {};
struct gev_tag {};

// Define a family of quantile functions
template<typename T>
double qua(double f, double location, double scale, double shape);

// Define a family of CDF functions
template<typename T>
double cdf(double x, double location, double scale, double shape);

template<typename distribution>
NumericVector quaxxx(const NumericVector & data, const NumericVector & location, const NumericVector & scale, const NumericVector & shape) {
  if (data.size() == location.size() && data.size() == scale.size() && data.size() == shape.size()) {
    // One set of distribution parameters for each observation.
    auto n = data.size();
    NumericVector ret = no_init(n);
    ret.attr("dim") = data.attr("dim");

    for (decltype(n) i = 0; i < n; i++) {
      ret[i] = qua<distribution>(data[i], location[i], scale[i], shape[i]);
    }

    return ret;
  } else if (location.size() == 1 && scale.size() == 1 && shape.size() == 1) {
    // Constant distribution parameters with multiple observations.
    auto n = data.size();
    NumericVector ret = no_init(n);
    ret.attr("dim") = data.attr("dim");

    for (decltype(n) i = 0; i < n; i++) {
      ret[i] = qua<distribution>(data[i], location[0], scale[0], shape[0]);
    }

    return ret;
  } else if (data.size() == 1 && (location.size() == scale.size() && location.size() == shape.size())) {
    // Constant observation, multiple distribution parameters
    auto n = location.size();
    NumericVector ret = no_init(n);
    ret.attr("dim") = location.attr("dim");
    n = location.size();

    for (decltype(n) i = 0; i < n; i++) {
      ret[i] = qua<distribution>(data[0], location[i], scale[i], shape[i]);
    }

    return ret;
  }

  stop("Unexpected vector lengths.");
}

// Define a family of functions that computes the quantiles at each location of a vector
template<typename distribution>
NumericVector cdfxxx(const NumericVector & data, const NumericVector & location, const NumericVector & scale, const NumericVector & shape) {
  auto n = data.size();
  NumericVector ret = no_init(n);
  ret.attr("dim") = data.attr("dim");

  if (n == location.size() && n == scale.size() && n == shape.size()) {
    // One set of distribution parameters for each observation.
    for (decltype(n) i = 0; i < n; i++) {
      ret[i] = cdf<distribution>(data[i], location[i], scale[i], shape[i]);
    }
  } else if (location.size() == 1 && scale.size() == 1 && shape.size() == 1) {
    // Constant distribution parameters with multiple observations.
    for (decltype(n) i = 0; i < n; i++) {
      ret[i] = cdf<distribution>(data[i], location[0], scale[0], shape[0]);
    }
  } else {
    stop("Unexpected vector lengths.");
  }

  return ret;
}

// Define a family of functions that bias-corrects a forecast given distributions
// of past observations and retrospective forecasts.
template<typename distribution>
NumericMatrix forecast_correct(const NumericMatrix & data,
                               const NumericMatrix & obs_location,
                               const NumericMatrix & obs_scale,
                               const NumericMatrix & obs_shape,
                               const NumericMatrix & retro_location,
                               const NumericMatrix & retro_scale,
                               const NumericMatrix & retro_shape,
                               double extreme_cutoff,
                               double when_dist_undefined) {
  int rows = data.nrow();
  int cols = data.ncol();

  NumericMatrix corrected = no_init(rows, cols);

  double min_quantile = 1 / extreme_cutoff;
  double max_quantile = 1 - min_quantile;

  for (int j = 0; j < cols; j++) {
    for (int i = 0; i < rows; i++) {
      if (std::isnan(data(i, j))) {
        corrected(i, j) = data(i, j);
      } else {
        double quantile;

        if (std::isnan(retro_location(i, j)) || std::isnan(retro_scale(i, j)) || std::isnan(retro_shape(i, j))) {
          quantile = when_dist_undefined;
        } else {
          quantile = cdf<distribution>(data(i,j), retro_location(i, j), retro_scale(i,j), retro_shape(i,j));
        }

        quantile = std::min(quantile, max_quantile);
        quantile = std::max(quantile, min_quantile);

        if (std::isnan(obs_scale(i, j)) || std::isnan(obs_shape(i, j))) {
          corrected(i, j) = obs_location(i, j);
        } else {
          corrected(i, j) = qua<distribution>(quantile, obs_location(i, j), obs_scale(i, j), obs_shape(i, j));
        }
      }
    }
  }

  return corrected;
}

template<>
double qua<pe3_tag>(double f, double location, double scale, double shape) {
  if (std::isnan(f)) {
    return f;
  }

  if (shape < 1e-8) {
    return R::qnorm(f, location, scale, true, false);
  }

  double alpha = 4 / (shape*shape);
  double beta = std::abs(0.5*scale*shape);

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

  if (std::abs(shape) < 1e-6) {
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

//' Quantile function for the Pearson Type-III distribution
//'
//' The provided distribution parameters (\code{location}, \code{scale},
//' \code{shape}) must have either a length of \code{1}, or the same length
//' as \code{x}.
//'
//' @param x        vector of probabilities
//' @param location vector of location parameters
//' @param scale    vector of scale
//' @param shape    vector of shape parameters
//' @return quantiles associated with each probability \code{x}
//'
//' @export
// [[Rcpp::export]]
NumericVector quape3(const NumericVector & x,
                     const NumericVector & location,
                     const NumericVector & scale,
                     const NumericVector & shape) {
  return quaxxx<pe3_tag>(x, location, scale, shape);
}

//' Quantile function for the generalized extreme value (GEV) distribution
//'
//' @inheritParams quape3
//' @export
// [[Rcpp::export]]
NumericVector quagev(const NumericVector & x,
                     const NumericVector & location,
                     const NumericVector & scale,
                     const NumericVector & shape) {
  return quaxxx<gev_tag>(x, location, scale, shape);
}

//' Cumulative distribution function for the Pearson Type-III distribution
//'
//' The provided distribution parameters (\code{location}, \code{scale},
//' \code{shape}) must have either a length of \code{1}, or the same length
//' as \code{x}.
//'
//' @param x        vector of quantiles
//' @param location vector of location parameters
//' @param scale    vector of scale
//' @param shape    vector of shape parameters
//' @return probability assocated with each quantile \code{x}
//'
//' @export
// [[Rcpp::export]]
NumericVector cdfpe3(const NumericVector & x,
                     const NumericVector & location,
                     const NumericVector & scale,
                     const NumericVector & shape) {
  return cdfxxx<pe3_tag>(x, location, scale, shape);
}

//' Cumulative distribution function for the generalized extreme value (GEV) distribution
//'
//' @inheritParams cdfpe3
//' @export
// [[Rcpp::export]]
NumericVector cdfgev(const NumericVector & x,
                     const NumericVector & location,
                     const NumericVector & scale,
                     const NumericVector & shape) {
  return cdfxxx<gev_tag>(x, location, scale, shape);
}

//' Bias-correct a forecast using GEV distribution
//'
//' Bias-correct a forecast using quantile-matching on computed distributions
//' of retrospective forecasts and observations.
//'
//' @param data           matrix representing forecast values
//' @param obs_location   location parameter from observed data
//' @param obs_scale      scale parameter from observed data
//' @param obs_shape      shape parameter from observed data
//' @param retro_location location parameter from retrospective data
//' @param retro_scale    scale parameter from retrospective data
//' @param retro_shape    shape parameter from retrospective data
//' @param extreme_cutoff clamping value for computed forecast quantiles
//'        (\code{1/extreme_cutoff < quantile < 1 - 1/extreme_cutoff})
//' @param when_dist_undefined assumed quantile of forecast when
//'        retrospective distribution is undefined
//'
//' @return a matrix with a corrected forecast
//'
//' @export
// [[Rcpp::export]]
NumericMatrix gev_forecast_correct(const NumericMatrix & data,
                                   const NumericMatrix & obs_location,
                                   const NumericMatrix & obs_scale,
                                   const NumericMatrix & obs_shape,
                                   const NumericMatrix & retro_location,
                                   const NumericMatrix & retro_scale,
                                   const NumericMatrix & retro_shape,
                                   double extreme_cutoff,
                                   double when_dist_undefined) {
  return forecast_correct<gev_tag>(data, obs_location, obs_scale, obs_shape, retro_location, retro_scale, retro_shape, extreme_cutoff, when_dist_undefined);
}

//' Bias-correct a forecast using Pearson Type-III distribution
//'
//' Bias-correct a forecast using quantile-matching on computed distributions
//' of retrospective forecasts and observations.
//'
//' @inheritParams gev_forecast_correct
//' @export
// [[Rcpp::export]]
NumericMatrix pe3_forecast_correct(const NumericMatrix & data,
                                   const NumericMatrix & obs_location,
                                   const NumericMatrix & obs_scale,
                                   const NumericMatrix & obs_shape,
                                   const NumericMatrix & retro_location,
                                   const NumericMatrix & retro_scale,
                                   const NumericMatrix & retro_shape,
                                   double extreme_cutoff,
                                   double when_dist_undefined) {
  return forecast_correct<pe3_tag>(data, obs_location, obs_scale, obs_shape, retro_location, retro_scale, retro_shape, extreme_cutoff, when_dist_undefined);
}

//' Compute a sample quantile of a given vector. NA values are ignored.
//'
//' This function is provided for improved performance over the built-in
//' \code{quantile} function. Interpolation is performed using the default
//' method 7 specified in documentation for \code{quantile}.
//'
//' @param v a vector of numeric values, possibly contining NAs
//' @param q quantile to compute
//'
//' @return sample quantile \code{q} of \code{v}
//'
//' @export
// [[Rcpp::export]]
double wsim_quantile(const NumericVector & v, double q) {
  if (q < 0 || q > 1)
    return NA_REAL;

  NumericVector y = clone(v);
  auto end = std::remove_if(y.begin(), y.end(), [](double d) { return std::isnan(d); });
  std::sort(y.begin(), end);
  int n = std::distance(y.begin(), end);

  if (n == 0)
    return NA_REAL;

  if (q == 1)
    return *(std::prev(end));

  int j = q*(n-1);
  double f = q*(n-1) - floor(q*(n-1));

  return (1-f)*y[j] + f*(y[j+1]);
}
