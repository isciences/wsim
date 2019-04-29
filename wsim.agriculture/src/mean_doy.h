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

#ifndef MEAN_DOY_H
#define MEAN_DOY_H

#include <cmath>
#include <limits>

template<typename T>
static double mean_doy(const T& begin, const T& end) {
  double sum_sin = 0;
  double sum_cos = 0;
  bool any_values_defined = false;
  
  constexpr double pi = 3.14159265358979323846;
  constexpr double doy2rad = 2*pi/365;
  
  for(auto it = begin; it != end; it++) {
    // Tried using sincos from math.h here, behind ifdef for _GNU_SOURCE.
    // No performance improvment.
    if (!std::isnan(*it)) {
      sum_sin += std::sin((*it - 1)*doy2rad);
      sum_cos += std::cos((*it - 1)*doy2rad);
      any_values_defined = true; 
    }
  }
  
  if (!any_values_defined) {
    return std::numeric_limits<double>::quiet_NaN();
  }
  
  double mean_r = std::atan2(sum_sin, sum_cos);
  
  if (mean_r < 0)
    mean_r += 2*pi;
  
  int doy = 1 + std::round(mean_r/doy2rad); 
  
  if (doy > 365)
    doy -= 365;
  
  return doy;
}

#endif

