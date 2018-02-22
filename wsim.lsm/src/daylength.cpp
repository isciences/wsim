// Copyright (c) 2018 ISciences, LLC.
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

#include <Rcpp.h>
using namespace Rcpp;

double get_sun_lat(int days_since_1900) {
  // "tj" is number of Julian centuries from 1900 Jan 0d 12h to
  // 0h UT of current day
  long double tj = days_since_1900 / 36525.0;
  long double tjsq = tj * tj;

  // 	Compute eccentricity, mean obliquity, mean anomaly
  //
  // "mean_anomaly" is mean anomaly (Earth orbit angle swept at mean orbital rate)
  // "eccentricity" is eccentricity of Earth's orbit
  // "mean_obliquity" is mean obliquity of ecliptic (inclination of orbit)
  long double mean_anomaly = (358.475833 +
    fmodl((0.985600267 * days_since_1900),
          360.) - 0.150E-3*tjsq - 0.3E-5*pow(tj,3)) * PI / 180;

  mean_anomaly = fmodl(mean_anomaly, 2*PI);

  long double eccentricity = 0.01675104 - 0.4180E-4*tj - 0.126E-6*tjsq;

  long double mean_obliquity = (23.4522944 - 0.0130125*tj - 0.164E-5*tjsq +
    0.503E-6*powl(tj,3)) * PI / 180;

  // Compute true anomaly, mean longitude of perihelion
  //
  // "true_anomaly" is true anomaly, angle of Sun from perihelion
  // "peri_long" is mean longitude of perihelion
  //
  // Bessel function expansion
  long double true_anomaly = mean_anomaly +
    (2.0*eccentricity - 0.24*(eccentricity*eccentricity) +
    5.0/96.0*powl(eccentricity, 5)) * sinl(mean_anomaly) +
    (1.25*(eccentricity*eccentricity) -
    11.0/24.0*powl(eccentricity, 4)) *
    sinl(2.0*mean_anomaly) +
    (13.0/12.0*powl(eccentricity, 3) -
    43.0/64.0*powl(eccentricity, 5)) *
    sinl(3.0*mean_anomaly) +
    (103.0/960.*powl(eccentricity, 4)) * sinl(4.0*mean_anomaly) +
    (1097.0/960.0*powl(eccentricity, 5)) * sinl(5.0*mean_anomaly);

  long double peri_long = (281.220833 + 0.470684E-4*days_since_1900 +
    0.453E-3*tjsq + 0.3E-5*powl(tj, 3)) * PI / 180;

  long double true_longitude = fmodl(true_anomaly + peri_long, 2*PI);

  return mean_obliquity * sinl(true_longitude);
}

//' Determine if a given year is a leap year
//'
//' @param y integer representation of year
//' @return TRUE if the given year is a leap year
// [[Rcpp::export]]
bool is_leap_year(int y) {
  // Every four years is a leap year, except for years that are
  // divisible by 100 (unless they're also divisible by 400)
  return !(y % 4) && (y % 100 || !(y % 400));
}

// Return the number of days since January 1, 1900
int days1900(int yyyyddd) {
  int y = yyyyddd / 1000;
  int d = yyyyddd % 1000;
  int ct = 0;

  for (int yp=1900; yp < y; yp++) {
    ct += 365 + is_leap_year(yp);
  }

  return ct + d - 1;
}

// Return the number of daylight hours, given earth and sun latitudes in radians
//
// [[Rcpp::export]]
double day_hours(double sun_lat, double earth_lat) {
  double clon = -tan(earth_lat) * tan(sun_lat);
  if (clon >= 1.0)
    return 0.0;
  if (clon <= -1.0)
    return 24.0;

  return 24.0 * acos(clon) / PI;
}

static const int MONTH_DAYS[] = { -1, 31, -1, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
int days_in_month(int year, int month) {
  if (month == 2) {
    return is_leap_year(year) ? 29 : 28;
  }
  return MONTH_DAYS[month];
}

int day_of_year(int year, int month, int day) {
  switch(month) {
    case 12: day += 30;
    case 11: day += 31;
    case 10: day += 30;
    case  9: day += 31;
    case  8: day += 31;
    case  7: day += 30;
    case  6: day += 31;
    case  5: day += 30;
    case  4: day += 31;
    case  3: day += is_leap_year(year) ? 29 : 28;
    case  2: day += 31;
  }

  return day;
}

//' Return the day length at given latitude(s)
//'
//' @param latitudes a vector of latitudes
//' @param year numeric year
//' @param month numeric month
//' @param day numeric day of month
//' @return day length in hours
//'
//' @export
// [[Rcpp::export]]
NumericVector day_length(const NumericVector & latitudes, int year, int month, int day) {
  int num_lats = latitudes.size();
  int yyyyddd = year*1000 + day_of_year(year, month, day);
  double sun_lat = get_sun_lat(days1900(yyyyddd));
  NumericVector day_lengths(num_lats);

  for (int i = 0; i < num_lats; i++) {
    day_lengths[i] = day_hours(sun_lat, latitudes[i] * PI / 180.0);
  }

  return day_lengths;
}

//' Return the monthly average day length at given latitude(s)
//'
//' @param latitudes a vector of latitudes
//' @param year numeric year
//' @param month numeric month
//' @return day length in hours
//'
//' @export
// [[Rcpp::export]]
NumericVector average_day_length(const NumericVector & latitudes, int year, int month) {
  int num_lats = latitudes.size();
  int num_days = days_in_month(year, month);
  NumericVector day_lengths(num_lats);

  for (int i = 1; i <= num_days; i++) {
    day_lengths += day_length(latitudes, year, month, i);
  }

  return day_lengths / num_days;
}
