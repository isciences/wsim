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

// [[Rcpp::plugins(cpp1y)]]
#include <Rcpp.h>

//' Disaggregate a matrix by duplicating each cell a fixed number of times
//' 
//' @param mat    matrix to disaggregate
//' @param factor number of times to copy each row and column 
//' @return matrix having dimensions of \code{dim(mat)*factor}
//' 
//' @export
//[[Rcpp::export]]
Rcpp::NumericMatrix disaggregate (const Rcpp::NumericMatrix & mat, int factor) {
  auto rows = mat.rows();
  auto cols = mat.cols();
  
  if (factor < 1) {
    Rcpp::stop("Invalid disaggregation factor");  
  }
    
  Rcpp::NumericMatrix out = Rcpp::no_init(rows*factor, cols*factor);
  
  for (decltype(cols) j = 0; j < cols; j++) {
    for (decltype(rows) i = 0; i < rows; i++) {
      for (int q = 0; q < factor; q++) {
        for (int p = 0; p < factor; p++) {
          out(i*factor + p, j*factor + q) = mat(i, j);
        }
      }
    }
  }
  
  return out;
}

template<typename BinOp>
Rcpp::NumericMatrix disaggregate_pfun_impl(
    const Rcpp::NumericMatrix & a,
    const Rcpp::NumericMatrix & b,
    BinOp op) {
  
  auto rows = a.rows();
  auto cols = a.cols();
  auto factor = a.rows() / b.rows();
  
  Rcpp::NumericMatrix out = Rcpp::no_init(rows, cols);
  
  for (decltype(cols) j = 0; j < cols; j++) {
    for (decltype(rows) i = 0; i < rows; i++) {
      out(i, j) = op(a(i, j), b(i/factor, j/factor));  
    }
  }
  
  return out;
}

template<typename BinOp>
static auto na_ignore(BinOp op) {
  return [op](const double & a, const double & b) {
    if (std::isnan(a)) {
      if (std::isnan(b)) {
        return NA_REAL;
      } else {
        return b;
      }
    } else if (std::isnan(b)) {
      return a;
    } else {
      return op(a, b);
    }
  };
}

//[[Rcpp::export]]
Rcpp::NumericMatrix disaggregate_pfun(const Rcpp::NumericMatrix & m1,
                                      const Rcpp::NumericMatrix & m2,
                                      const std::string & op,
                                      bool na_rm) {
  const Rcpp::NumericMatrix& a = m1.size() > m2.size() ? m1 : m2;
  const Rcpp::NumericMatrix& b = m1.size() > m2.size() ? m2 : m1;
  
  auto rows = a.rows();
  auto cols = a.cols();
  
  auto factor = rows / b.rows();
  if (b.rows()*factor != rows || b.cols()*factor != cols) {
    Rcpp::stop("Dimensions of two matrices may only differ by a constant integer factor.");
  }
  
  if (op == "sum") {
    auto sum = ([](const double & a, const double & b) { return a + b; });
    if (na_rm) {
      return disaggregate_pfun_impl(a, b, na_ignore(sum));
    } else {
      return disaggregate_pfun_impl(a, b, sum);
    }
  } else if (op == "difference") {
    auto difference = ([](const double & a, const double & b) { return a - b; });
    if (na_rm) {
      return disaggregate_pfun_impl(a, b, na_ignore(difference));
    } else {
      return disaggregate_pfun_impl(a, b, difference);
    }
  } else if (op == "product") {
    auto product = ([](const double & a, const double & b) { return a * b; });
    if (na_rm) {
      return disaggregate_pfun_impl(a, b, na_ignore(product));
    } else {
      return disaggregate_pfun_impl(a, b, product);
    }
  } else if (op == "quotient") {
    auto quotient = ([](const double & a, const double & b) { return a / b; });
    if (na_rm) {
      return disaggregate_pfun_impl(a, b, na_ignore(quotient));
    } else {
      return disaggregate_pfun_impl(a, b, quotient);
    }
  } else {
    Rcpp::stop("Unknown operation.");
  }
}