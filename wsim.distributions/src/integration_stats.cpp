// Copyright (c) 2018-2020 ISciences, LLC.
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

// This file provides optimized implementations of various
// simple statistics functions (min, max, avg, etc.) used
// by wsim_integrate.
//
// These functions are substantially faster than calling
// "apply" with the native R versions. A benchmark example
// with the "sum" function is below.
//
// stack <- array(runif(1e6), dim=c(100, 100, 100))
// stack[sample.int(1e6, size=1e4)] <- NA
// microbenchmark(
//   aperm(apply(stack, MARGIN=c(2,1), FUN=function(x) sum(x, na.rm=TRUE))),
//   stack_sum(stack)
// )
//
// # Unit: milliseconds
// #   expr                   min         lq        mean     median         uq       max neval
// #   aperm(apply...)  54.258379 111.651094  110.963339 118.903153 126.053525 186.31030   100
// #   stack_sum(stack)  3.654879   3.822992    5.137139   4.211196   4.823422  70.25946   100
//

// Define types for functions that either:
//
// a) accept a vector and return a scalar (VectorToDoubleFunction), or
// b) accept a vector and return a vector (VectorToVectorFunction)
//
// In both cases, the function receives a vector of arguments, and an
// integer number of arguments. Any arguments at indices between
// argv.size() and argc should be interpreted as NA.

// Apply function f over each slice [i, j, ] in an array
// f must return a scalar
template<typename Function>
NumericVector stack_apply (const NumericVector & v,
                           Function&& f,
                           bool remove_na) {
  IntegerVector dims = v.attr("dim");
  if (dims.length() < 2 || dims.length() > 3) {
    throw std::invalid_argument("Expected array of 2 or 3 dimensions");
  }
  const int cells_per_level = dims[0]*dims[1];
  const int depth = dims.length() == 2 ? 1 : dims[2];

  // Create an output array of dimensions matching the input
  NumericVector out = no_init(cells_per_level);
  out.attr("dim") = NumericVector::create(dims[0], dims[1]);

  // Create mutable vector to hold arguments for `f`
  std::vector<double> f_args(depth);

  for (int j = 0; j < dims[0]; j++) {
    int jblock = j*dims[1];

    for (int i = 0; i < dims[1]; i++) {
      int argc = 0;
      for (int k = 0; k < depth; k++) {
        double val = v[k*cells_per_level + jblock + i];
        if (!remove_na || !std::isnan(val)) {
          f_args[argc++] = val;
        }
      }

      out[jblock + i] = f(f_args, argc);
    }
  }

  return out;
}

// Apply function f over each slice [i, j, ] in an array
// f must return a vector of length `depth_out`
template<typename Function>
NumericVector stack_apply (const NumericVector & v,
                           Function&& f,
                           int depth_out,
                           bool remove_na) {
  const IntegerVector dims = v.attr("dim");
  if (dims.length() < 2 || dims.length() > 3) {
    throw std::invalid_argument("Expected array of 2 or 3 dimensions");
  }

  const int cells_per_level = dims[0]*dims[1];
  const int depth = dims[2];

  // Create an output array of dimensions matching the input
  NumericVector out = no_init(cells_per_level*depth_out);
  out.attr("dim") = NumericVector::create(dims[0], dims[1], depth_out);

  // Create mutable vector to hold arguments for `f`
  std::vector<double> f_args(depth);

  for (int j = 0; j < dims[0]; j++) {
    int jblock = j*dims[1];

    for (int i = 0; i < dims[1]; i++) {
      int argc = 0;
      for (int k = 0; k < depth; k++) {
        double val = v[k*cells_per_level + jblock + i];
        if (!remove_na || !std::isnan(val)) {
          f_args[argc++] = val;
        }
      }

      std::vector<double> result = f(f_args, argc);

      for (int k = 0; k < std::min(depth_out, (int) result.size()); k++) {
        out[k*cells_per_level + jblock + i] = result[k];
      }
    }
  }

  return out;
}

// Compute the min of first n elements in a vector
static inline double min_n (const std::vector<double> & v, int n) {
  if (n == 0) {
    return NA_REAL;
  }
  return *std::min_element(v.begin(), std::next(v.begin(), n));
}

// Compute the max of first n elements in a vector
static inline double max_n (const std::vector<double> & v, int n) {
  if (n == 0) {
    return NA_REAL;
  }
  return *std::max_element(v.begin(), std::next(v.begin(), n));
}

// Compute index of the max defined element in a vector
// Returned value is indexed beginning at 1
static inline double which_max_n (const std::vector<double> & v, int n) {
  int max_i;
  bool found_defined = false;

  for (int i = 0; i < n; i++) {
    if (!std::isnan(v[i])) {
      if (!found_defined) {
        found_defined = true;
        max_i = i;
      } else if (v[i] > v[max_i]) {
        max_i = i;
      }
    }
  }

  if (!found_defined) {
    return NA_REAL;
  }

  return 1 + max_i;
}

// Compute index of the min defined element in a vector
// Returned value is indexed beginning at 1
static inline double which_min_n (const std::vector<double> & v, int n) {
  int min_i;
  bool found_defined = false;

  for (int i = 0; i < n; i++) {
    if (!std::isnan(v[i])) {
      if (!found_defined) {
        found_defined = true;
        min_i = i;
      } else if (v[i] < v[min_i]) {
        min_i = i;
      }
    }
  }

  if (!found_defined) {
    return NA_REAL;
  }

  return 1 + min_i;
}

// Compute the mean of first n elements in a vector
static inline double mean_n (const std::vector<double> & v, int n) {
  if (n == 0) {
    return NA_REAL;
  }
  return std::accumulate(v.begin(), std::next(v.begin(), n), 0.0) / n;
}

// Compute the sum of first n elements in a vector
static inline double sum_n (const std::vector<double> & v, int n) {
  return std::accumulate(v.begin(), std::next(v.begin(), n), 0.0);
}

// Compute the fraction of first n elements in a vector that are defined
static inline double frac_defined_n (const std::vector<double> & v, int n) {
  return n / ( (double) v.size() );
}

// Compute the fraction of defined values that are above zero
static inline double frac_defined_above_zero_n (const std::vector<double> & v, int n) {
  if (n == 0) {
    return NA_REAL;
  }

  return std::count_if(v.begin(),
                       std::next(v.begin(), n),
                       [](double d) { return d > 0; }) / ( (double) n);
}

// Compute a sample quantile of a given vector.
//
// This function is provided for improved performance over the built-in
// \code{quantile} function. Interpolation is performed using the default
// method 7 specified in documentation for \code{quantile}.
//
// @param v a vector of numeric values with NAs removed
// @param n number of values in the vector to consider (may be less than
//          the length of the vector)
// @param q quantile to compute
//
// @return sample quantile \code{q} of \code{v}
static double quantile (const std::vector<double> & v, int n, double q) {
  if (q < 0 || q > 1)
    return NA_REAL;

  if (n == 0)
    return NA_REAL;

  if (q == 1)
    return *(std::next(v.begin(), n-1));

  std::vector<double> v2 (n);
  v2.assign(v.begin(), std::next(v.begin(), n));
  std::sort(v2.begin(), v2.end());

  int j = q*(n-1);
  double f = q*(n-1) - floor(q*(n-1));

  return (1-f)*v2[j] + f*(v2[j+1]);
}

template<typename V, typename W>
static double weighted_quantile(const V & values, const W & weights, int _, double q) {
  // Compute a quantile from weighted values, linearly
  // interpolating between points.
  // Uses a formula from https://stats.stackexchange.com/a/13223
  //
  // Unlike spatstat::weighted.quantile, it matches the default behavior of the
  // base R stats::quantile function when all weights are equal.
  //
  // Unlike Hmisc::wtd.quantile, quantiles always change as the probability is
  // changed, unless there are duplicate values. Hmisc::wtd.quantile also
  // produces nononsense results for non-integer weights; see
  // https://github.com/harrelfe/Hmisc/issues/97

  struct elem {
    elem(double _x, double _w) : x(_x), w(_w), cumsum(0) {}

    double x;
    double w;
    double cumsum;
    double s;
  };

  if (q < 0 || q > 1)
    return NA_REAL;

  double sum_w = 0;
  std::vector<elem> elems;
  elems.reserve(values.size());

  // accumulate the defined values and their weights
  auto vsize = values.size();
  for (size_t i = 0; i < vsize; i++) {
    auto& v = values[i];

    if (!std::isnan(v)) {
      if (weights[i] < 0) {
        Rcpp::stop("Negative weights are not supported.");
      }
      if (std::isnan(weights[i])) {
        Rcpp::stop("Undefined weights are not supported.");
      }

      elems.emplace_back(values[i], weights[i]);
      sum_w += weights[i];
    }
  }

  if (sum_w == 0) {
    Rcpp::stop("All weights are zero");
  }

  auto n = elems.size();
  if (n == 0) {
    return NA_REAL;
  }

  std::sort(elems.begin(), elems.end(), [](const elem& a, const elem& b) { return a.x < b.x; });

  elems[0].cumsum = elems[0].w;
  elems[0].s = 0;
  for (size_t i = 1; i < n; i++) {
    elems[i].cumsum = elems[i-1].cumsum + elems[i].w;
    elems[i].s = i*elems[i].w + (n-1)*elems[i-1].cumsum;
  }
  double sn = (n-1)*sum_w;

  size_t left = 0; // index of last element having a probablity <= q
  while (left < (n-1) && elems[left+1].s <= q*sn) {
    left++;
  }

  // Replace w/check on q == 0 or q == 1?
  if (left == (n-1)) {
    return elems[left].x;
  }

  const elem& a = elems[left];
  const elem& b = elems[left + 1];

  // linearly interpolate p between quantiles of
  // values to the left and right
  return  a.x + (q*sn - a.s)*(b.x - a.x)/(b.s - a.s);
}

//' Compute the sum of defined elements for each row and col in a 3D array
//'
//' @param v 3D array that may contain NA values
//'
//' @return a matrix with the sum for each [row, col, ]
//' @export
// [[Rcpp::export]]
NumericVector stack_sum (const NumericVector & v) {
  return stack_apply(v, sum_n, true);
}

//' Compute the mean defined element for each row and col in a 3D array
//'
//' @param v 3D array that may contain NA values
//'
//' @return a matrix with the mean value for each [row, col, ]
//' @export
// [[Rcpp::export]]
NumericVector stack_mean (const NumericVector & v) {
  return stack_apply(v, mean_n, true);
}

//' Compute the minimum defined element for each row and col in a 3D array
//'
//' @param v 3D array that may contain NA values
//'
//' @return a matrix with the minimum value for each [row, col, ]
//' @export
// [[Rcpp::export]]
NumericVector stack_min (const NumericVector & v) {
  return stack_apply(v, min_n, true);
}

//' Compute the index of the minimum defined element for each row and col in a 3D array
//'
//' Returned value is indexed beginning at 1
//'
//' @param v 3D array that may contain NA values
//'
//' @return a matrix with the minimum index for each [row, col, ]
//' @export
// [[Rcpp::export]]
NumericVector stack_which_min (const NumericVector & v) {
  return stack_apply(v, which_min_n, false);
}

//' Compute the maximum defined element for each row and col in a 3D array
//'
//' Returned value is indexed beginning at 1
//'
//' @param v 3D array that may contain NA values
//'
//' @return a matrix with the maximum value for each [row, col, ]
//' @export
// [[Rcpp::export]]
NumericVector stack_max (const NumericVector & v) {
  return stack_apply(v, max_n, true);
}

//' Compute the index of the maximum defined element for each row and col in a 3D array
//'
//' @param v 3D array that may contain NA values
//'
//' @return a matrix with the maximum index for each [row, col, ]
//' @export
// [[Rcpp::export]]
NumericVector stack_which_max (const NumericVector & v) {
  return stack_apply(v, which_max_n, false);
}

//' Compute the number of defined elements for each row and col in a 3D array
//'
//' @param v 3D array that may contain NA values
//'
//' @return a matrix with the computed count for each [row, col, ]
//' @export
// [[Rcpp::export]]
NumericVector stack_num_defined (const NumericVector & v) {
  return stack_apply(v, [](std::vector<double> &, int count) {
    return static_cast<double>(count);
  }, true);
}

//' Compute the fraction of defined elements for each row and col in a 3D array
//'
//' @param v 3D array that may contain NA values
//'
//' @return a matrix with the computed fraction for each [row, col, ]
//' @export
// [[Rcpp::export]]
NumericVector stack_frac_defined (const NumericVector & v) {
  return stack_apply(v, frac_defined_n, true);
}

//' Compute the fraction of defined elements above zero for each row and col in a 3D array
//'
//' @param v 3D array that may contain NA values
//'
//' @return a matrix with the computed fraction for each [row, col, ]
//' @export
// [[Rcpp::export]]
NumericVector stack_frac_defined_above_zero (const NumericVector & v) {
  return stack_apply(v, frac_defined_above_zero_n, true);
}

//' Compute a given quantile of defined elements for each row and col in a 3D array
//'
//' @param v 3D array that may contain NA values
//' @param q a quantile to compute, q within [0,1]
//'
//' @return a matrix with the specified quantile for each [row, col, ]
//' @export
// [[Rcpp::export]]
NumericVector stack_quantile (const NumericVector & v, double q) {
  return stack_apply(v, std::bind(quantile, std::placeholders::_1, std::placeholders::_2, q), true);
}

//' Compute a given weighted quantile of defined elements for each row and col in a 3D array
//'
//' @param v a 3D array that may contain NA values
//' @param w a 2D vector of weights, having the same length as the third dimension of \code{v}
//' @param q a quantile to compute, q within [0, 1]
//'
//' @return a matrix with the specified quantile for each [row, col, ]
//' @export
// [[Rcpp::export]]
NumericVector stack_weighted_quantile (const NumericVector & v, const NumericVector & w, double q) {
  if (Rf_isNull(v.attr("dim"))) {
    Rcpp::stop("stack_weighted_quantile called with non-array values");
  }

  IntegerVector vdim = v.attr("dim");

  if (vdim.size() != 3) {
    Rcpp::stop("stack_weighted_quantile operates on three-dimensional arrays only");
  }

  auto wlen = w.size();
  if (wlen != vdim[2]) {
    Rcpp::stop("length of weights must equal length of 3rd dimension of value array");
  }

  return stack_apply(v, [&w, q](const std::vector<double> & x, int n) {
    return weighted_quantile(x, w, n, q);
  }, false); // don't ask stack_apply to remove our null values; we need to handle them
             // internally so that we can keep correspondence with weights
}

//' Compute the median of defined elementsn for each row and col in a 3D array
//'
//' @param v 3D array that may contain NA values
//'
//' @return a matrix with the median for each [row, col, ]
//' @export
// [[Rcpp::export]]
NumericVector stack_median (const NumericVector & v) {
  return stack_apply(v, std::bind(quantile, std::placeholders::_1, std::placeholders::_2, 0.50), true);
}

//' Sort each slice [i, j, ] in an array
//'
//' @param v 3D array that may contain NA values
//'
//' @return a matrix with the median for each [row, col, ]
//' @export
// [[Rcpp::export]]
NumericVector stack_sort(const NumericVector & v) {
  IntegerVector dim = v.attr("dim");

  if (dim.size() < 3) {
    return v;
  }

  return stack_apply(v, [](const std::vector<double> & x, int n) {
    std::vector<double> out(x.size());
    std::copy_n(x.begin(), n, out.begin());
    std::sort(out.begin(), std::next(out.begin(), n));
    std::fill(std::next(out.begin(), n), out.end(), NA_REAL);

    return out;
  }, dim[2], true);
}

// Sort each slice [i, j, ] in an array
// [[Rcpp::export]]
NumericVector stack_sort2(const NumericVector & v) {
  const IntegerVector dims = v.attr("dim");

  if (dims.length() < 2 || dims.length() > 3) {
    throw std::invalid_argument("Expected array of 2 or 3 dimensions");
  }

  if (dims.length() == 2) {
    return v;
  }

  const int cells_per_level = dims[0]*dims[1];
  const int depth = dims[2];

  // Create an output array of dimensions matching the input
  NumericVector out = no_init(v.size());
  out.attr("dim") = dims;

  // Create mutable vector to hold defined elements to sort
  std::vector<double> pixel_values(depth);

  for (int j = 0; j < dims[0]; j++) {
    int jblock = j*dims[1];

    for (int i = 0; i < dims[1]; i++) {
      int argc = 0;
      for (int k = 0; k < depth; k++) {
        double val = v[k*cells_per_level + jblock + i];
        if (!std::isnan(val)) {
          pixel_values[argc++] = val;
        }
      }

      std::sort(pixel_values.begin(), std::next(pixel_values.begin(), argc));

      for (int k = 0; k < argc; k++) {
        out[k*cells_per_level + jblock + i] = pixel_values[k];
      }
      for (int k = argc; k < depth; k++) {
        out[k*cells_per_level + jblock + i] = NA_REAL;
      }
    }
  }

  return out;
}
