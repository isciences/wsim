// [[Rcpp::plugins(cpp11)]]
#include <Rcpp.h>
using namespace Rcpp;

//' Replace NA values with a specified constant
//'
//' @param v                 a numeric vector that may
//'                          contain NA values
//' @param replacement_value a constant with with NA values
//'                          should be replaced
//'
//' @return a copy of \code{v} with NA values replaced by
//'         \code{replacement_value}
//' @export
// [[Rcpp::export]]
NumericVector coalesce(const NumericVector & v, double replacement_value) {
  NumericVector res = no_init(v.size());
  res.attr("dim") = v.attr("dim");

  std::replace_copy_if(v.begin(),
                       v.end(),
                       res.begin(),
                       [](double x) { return std::isnan(x); },
                       replacement_value
                       );

  return res;
}
