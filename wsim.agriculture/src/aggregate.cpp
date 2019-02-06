// Copyright (c) 2019 ISciences, LLC.
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

#include "mean_doy.h"


//[[Rcpp::export]]
Rcpp::NumericMatrix aggregate_sum (const Rcpp::NumericMatrix & mat, int factor) {
  auto rows = mat.rows();
  auto cols = mat.cols();
  
  // TODO check divisibility
  Rcpp::NumericMatrix out = Rcpp::no_init(rows/factor, cols/factor);
  std::fill(out.begin(), out.end(), NA_REAL);
  
  for (decltype(cols) j = 0; j < cols; j++) {
    for (decltype(rows) i = 0; i < rows; i++) {
      if (!std::isnan(mat(i, j))) {
        if (std::isnan(out(i/factor, j/factor))) {
          out(i/factor, j/factor) = mat(i, j);
        } else {
          out(i/factor, j/factor) += mat(i, j);
        }
      }
    }
  }
  
  return out;
}

//[[Rcpp::export]]
Rcpp::NumericMatrix aggregate_mean (const Rcpp::NumericMatrix & mat, int factor) {
  using index_t=decltype(mat.rows());
  
  auto rows = mat.rows();
  auto cols = mat.cols();
  
  // TODO check divisibility
  Rcpp::NumericMatrix out = Rcpp::no_init(rows/factor, cols/factor);
  std::fill(out.begin(), out.end(), NA_REAL);
  Rcpp::IntegerMatrix out_n(rows/factor, cols/factor);
  
  for (index_t j = 0; j < cols; j++) {
    for (index_t i = 0; i < rows; i++) {
      if (!std::isnan(mat(i, j))) {
        if (std::isnan(out(i/factor, j/factor))) {
          out(i/factor, j/factor) = mat(i, j);
        } else {
          out(i/factor, j/factor) += mat(i, j);
        }
        out_n(i/factor, j/factor) += 1;
      }
    }
  }
  
  for (index_t j = 0; j < cols / factor; j++) {
    for (index_t i = 0; i < rows / factor; i++) {
      if (out_n(i, j) == 0) {
        out(i, j) = NA_REAL;
      } else {
        out(i, j) = out(i, j) / out_n(i, j);
      }
    }
  }
  
  return out;
}

//' Aggregate a matrix, reducing a block of cells to a single cell by averaging the day of the year
//' 
//' @param mat    a matrix
//' @param factor factor by which to reduce the matrix; every \code{factor} rows will
//'               be reduced to a single row, and every \code{factor} columns will be
//'               reduced to a single column.
//' @export
//[[Rcpp::export]]
Rcpp::NumericMatrix aggregate_mean_doy(const Rcpp::NumericMatrix & mat, int factor) {
  using index_t = decltype(mat.rows());  
  
  std::vector<double> vals;
  vals.reserve(factor*factor);
  size_t n_defined = 0;
  
  index_t rows = mat.rows() / factor;
  index_t cols = mat.cols() / factor;
  
  if (rows*factor != mat.rows()) {
    Rcpp::stop("Number of rows must be evenly divisible by factor.");
  }
  if (cols*factor != mat.cols()) {
    Rcpp::stop("Number of rows must be evenly divisible by factor.");
  }
  
  Rcpp::NumericMatrix out = Rcpp::no_init(rows, cols);
  for (index_t j = 0; j < cols; j++) {
    for (index_t i = 0; i < rows; i++) {
      vals.clear();
      n_defined = 0;
      
      for (index_t jj = 0; jj < factor; jj++) {
        for (index_t ii = 0; ii < factor; ii++) {
          double val = mat(i*factor + ii, j*factor + jj);
          if (!std::isnan(val)) {
            vals[n_defined++] = val;
          }
        }
      }
      
      out(i, j) = mean_doy(vals.begin(), std::next(vals.begin(), n_defined));
      if (std::isnan(out(i, j))) {
        out(i, j) = NA_REAL;
      }
    }
  }  
  
  return out;
}


// You can include R code blocks in C++ files processed with sourceCpp
// (useful for testing and development). The R code will be automatically 
// run after the compilation.
//

/*** R
mat <- rbind(
  c(1,2,3,NA,NA,NA),
  c(5,6,7,8, NA,NA)
)
aggregate_sum(mat, 2)
aggregate_mean(mat, 2)
aggregate_mean_doy(mat, 2)
*/