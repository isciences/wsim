// [[Rcpp::plugins(cpp11)]]
#include <Rcpp.h>
using namespace Rcpp;

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
