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
#include <fstream>
#include <sstream>
#include <string>

#include <Rcpp.h>

//' Parse a condensed crop calendar in the format used by MIRCA2000
//' 
//' @param filename     full path to crop calendar file
//' @param header_lines number of header lines to skip [default: 4]
//' @return             data frame with columns for unit_code, crop, 
//'                     subcrop, planting month, and harvesting month
//' @export
// [[Rcpp::export]]
Rcpp::DataFrame parse_mirca_condensed_crop_calendar(std::string filename, int header_lines=4) {
  std::ifstream infile(filename);
  
  for (size_t i = 0; i < header_lines; i++) {
    std::string header_line;
    getline(infile, header_line);  
  }
  
  std::vector<int32_t> units;
  std::vector<int16_t> crops;
  std::vector<int16_t> subcrops;
  std::vector<int16_t> plant_months;
  std::vector<int16_t> harvest_months;
  
  std::string line;
  while(getline(infile, line)) {
    std::istringstream iss(line);
    
    int64_t unit_code;
    int16_t crop_class;
    int16_t num_subcrops;
    
    iss >> unit_code;
    iss >> crop_class;
    iss >> num_subcrops;
    
    //Rcpp::Rcout << "unit " << unit_code << " class " << crop_class << " subcrops " << num_subcrops << std::endl;
    
    for(int16_t subcrop = 1; subcrop <= num_subcrops; subcrop++) {
      int16_t plant_month;
      int16_t harvest_month;
      double crop_area;
      
      iss >> crop_area;
      iss >> plant_month;
      iss >> harvest_month;
      
      units.push_back(unit_code);
      crops.push_back(crop_class);
      subcrops.push_back(subcrop);
      plant_months.push_back(plant_month);
      harvest_months.push_back(harvest_month);
      
      //Rcpp::Rcout << "  " << subcrop << " " << plant_month << " " << harvest_month << std::endl;
    }
  }
  
  infile.close();
  
  return Rcpp::DataFrame::create(
    Rcpp::Named("unit_code")=     Rcpp::wrap(units),
    Rcpp::Named("crop")=          Rcpp::wrap(crops),
    Rcpp::Named("subcrop")=       Rcpp::wrap(subcrops),
    Rcpp::Named("plant_month")=   Rcpp::wrap(plant_months),
    Rcpp::Named("harvest_month")= Rcpp::wrap(harvest_months)
  );
}