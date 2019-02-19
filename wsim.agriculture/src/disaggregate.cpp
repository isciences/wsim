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