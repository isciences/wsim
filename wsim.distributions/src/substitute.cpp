// [[Rcpp::plugins(cpp11)]]
#include <Rcpp.h>
using namespace Rcpp;

//' Substitute specifed values in a vector with replacements
//'
//' @param vals A vector in which some values should be replaced
//' @param subs A vector containing a sequence of replacement values,
//'             in the form val_1, replacement_1, val_2, replacement_2, ...
//'
//' @export
// [[Rcpp::export]]
NumericVector substitute(const NumericVector & vals,
                         const NumericVector & subs) {

  std::unordered_map<double, double> sub_map;
  NumericVector out(vals.size());
  out.attr("dim") = vals.attr("dim");

  for (int i = 1; i < subs.size(); i += 2) {
    sub_map[subs[i-1]] = subs[i];
  }

  std::transform(vals.cbegin(),
                 vals.cend(),
                 out.begin(),
                 [&](double val) {
                   auto lookup = sub_map.find(val);
                   if (lookup == sub_map.end()) {
                     return val;
                   } else {
                     return lookup->second;
                   }
                 });

  return out;
}
