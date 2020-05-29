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

static std::array<int, 3> get_dims3(const NumericVector & v) {
  std::array<int, 3> ret = { 1, 1, 1};

  if (v.hasAttribute("dim")) {
    IntegerVector dims = v.attr("dim");

    switch(dims.size()) {
      case 3: ret[2] = dims[2];
      case 2: ret[1] = dims[1];
      case 1: ret[0] = dims[0];
        break;
      default:
        throw std::invalid_argument("Expected array of <= 3 dimensions");
    }
  } else {
    ret[0] = v.size();
  }

  return ret;
}

template<typename ContainerType, typename ValueType>
struct ResultHolder {

  ResultHolder(ContainerType obj) {
    m_obj = std::move(obj);
  }

  size_t size() const {
    return m_obj.size();
  }

  const ValueType& operator[](size_t i) const {
    return m_obj[i];
  }

  ContainerType m_obj;
};

template<>
struct ResultHolder<double, double>
{
  ResultHolder(double obj) {
    m_obj = obj;
  }

  size_t size() const {
    return 1ul;
  }

  const double& operator[](size_t i) const {
    assert(i == 0);
    return m_obj;
  }

  double m_obj;
};


// Apply function f over each slice [i, j, ] in an array
// f must return a scalar
// f(v[i,j,-]) -> scalar
template<typename Function>
NumericVector stack_apply (const NumericVector & v,
                           Function&& f,
                           bool remove_na) {
  auto dims = get_dims3(v);
  const int cells_per_level = dims[0]*dims[1];
  const int depth = dims.size() == 2 ? 1 : dims[2];

  // Create mutable vector to hold arguments for `f`
  std::vector<double> f_args(depth);

  size_t depth_out = 0;

  // Probe the first cell to find the length of the output.
  for (size_t k = 0; k < depth; k++) {
    double val = v[k*cells_per_level];
    f_args[k] = val;

    ResultHolder<decltype(f(f_args, depth)), double> result(f(f_args, depth));
    depth_out = result.size();
  }

  // Create an output array of dimensions matching the input
  NumericVector out = no_init(cells_per_level*depth_out);
  if (depth_out == 1) {
    out.attr("dim") = NumericVector::create(dims[0], dims[1]);
  } else {
    out.attr("dim") = NumericVector::create(dims[0], dims[1], depth_out);
  }

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

      ResultHolder<decltype(f(f_args, argc)), double> result(f(f_args, argc));

      for (int k = 0; k < result.size(); k++) {
        out[k*cells_per_level + jblock + i] = result[k];
      }
    }
  }

  return out;
}

// f(v[i,j,-], m[i, j]) -> scalar
template<typename Function>
NumericVector stack_apply(const NumericVector & v,
                          const NumericVector & m,
                          Function&& f,
                          bool remove_na) {

  auto dims = get_dims3(v);

  const int cells_per_level = dims[0]*dims[1];
  const int depth = dims[2];

  auto mdims = get_dims3(m);
  if (mdims[2] != 1) {
      throw std::invalid_argument("Expected matrix.");
  }
  if (mdims[0] != dims[0] || mdims[1] != dims[1]) {
    Rcpp::Rcout << mdims[0] << " " << mdims [1] << " " << dims[0] << " " << dims[1] << std::endl;
    throw std::invalid_argument("Number of rows and columns in matrix must match companion array.");
  }

  // Create mutable vector to hold arguments for `f`
  std::vector<double> f_args(depth);

  size_t depth_out = 0;

  // Probe the first cell to find the length of the output.
  for (size_t k = 0; k < depth; k++) {
    double val = v[k*cells_per_level];
    f_args[k] = val;

    ResultHolder<decltype(f(m[0], f_args, depth)), double> result(f(m[0], f_args, depth));
    depth_out = result.size();
  }

  // Create an output array of dimensions matching the input
  NumericVector out = no_init(cells_per_level*depth_out);
  if (depth_out == 1) {
    out.attr("dim") = NumericVector::create(dims[0], dims[1]);
  } else {
    out.attr("dim") = NumericVector::create(dims[0], dims[1], depth_out);
  }

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

      ResultHolder<decltype(f(m[jblock+i],f_args,argc)), double> result(f(m[jblock + i], f_args, argc));

      for (int k = 0; k < result.size(); k++) {
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
  }, true);
}

//' Extract a slab of n elements from an array, with a variable starting point
//'
//' @param v     a three-dimemsional array
//' @param start a matrix containing start indices along the third dimension of \code{v}
//' @param n     the number of elements to extract along the third dimension
//' @param fill  a fill value to use where \code{start[i, j] < 1 | start[i, j] + n > dim(v)[3]}
//' @export
// [[Rcpp::export]]
NumericVector stack_select(const NumericVector & v, const NumericVector & start, const IntegerVector & n, const NumericVector & fill) {
  return stack_apply(v, start, [n, fill](double s, const std::vector<double> & x, int argc) {
    std::vector<double> out(n[0]);

    for(size_t i = 0; i < n[0]; i++) {
      auto j = i + s - 1;
      if (j >= argc || j < 0) {
        out[i] = fill[0];
      } else {
        out[i] = x[j];
      }
    }

    return out;
  }, false);
}

//' Compute the rank of each element in a matrix, returning the minimum in case of ties
//'
//' @param x   a matrix of values to rank
//' @param obs a 3D array of observations against which each value in x should be ranked
//'
//' @return the rank of \code{x} after it is added to \code{obs}, for each (i, j) in \code{x}
//' @export
// [[Rcpp::export]]
NumericVector stack_min_rank(const NumericVector & x, const NumericVector & obs) {
  return stack_apply(obs, x, [](double xi, const std::vector<double> & sorted_obs, int nobs) -> double {
    if (std::isnan(xi)) {
      return NA_REAL;
    }

    if (nobs == 0) {
      return 1;
    }

    auto o = std::lower_bound(sorted_obs.begin(), std::next(sorted_obs.begin(), nobs), xi);
    return std::distance(sorted_obs.begin(), o) + 1;
  }, true);
}

//' Compute the rank of each element in a matrix, returning the maximum in case of ties
//'
//' @param x   a matrix of values to rank
//' @param obs a 3D array of observations against which each value in x should be ranked
//'
//' @return the rank of \code{x} after it is added to \code{obs}, for each (i, j) in \code{x}
//' @export
// [[Rcpp::export]]
NumericVector stack_max_rank(const NumericVector & x, const NumericVector & obs) {
  return stack_apply(obs, x, [](double xi, const std::vector<double> & sorted_obs, int nobs) -> double {
    if (std::isnan(xi)) {
      return NA_REAL;
    }

    if (nobs == 0) {
      return 1;
    }

    auto o = std::upper_bound(sorted_obs.begin(), std::next(sorted_obs.begin(), nobs), xi);
    return std::distance(sorted_obs.begin(), o) + 1;
  }, true);
}
