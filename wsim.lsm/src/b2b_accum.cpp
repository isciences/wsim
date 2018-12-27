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

// [[Rcpp::plugins(cpp11)]]
#include <Rcpp.h>
#include <stack>
using namespace Rcpp;

#define DEBUG false

using basin_id = int;

struct Basin {
  basin_id id;
  Basin* downstream;

  double flow;
  double flow_out;
  double flow_downstream;

  std::vector<Basin*> upstream;
  bool visited;

  Basin(basin_id id, double flow) :
    id{id},
    downstream{nullptr},
    flow{flow},
    flow_out{0},
    flow_downstream{0},
    visited{false} {}

  void set_downstream(Basin* b) {
    downstream = b;
  }

  void add_upstream(Basin* b) {
    upstream.push_back(b);
  }

  bool is_headwater() const {
    return upstream.empty();
  }

  bool is_mouth_of_river() const {
    return downstream == nullptr;
  }
};

enum class AccumulationType {
  FLOW_OUT,
  FLOW_DOWNSTREAM
};

// Find the flow generated either upstream or downstream of a given set of basins
// Processing begins at downstream basins (those that empty into the ocean, or some
// other sink identified with a basin_id < 0) and works upstream until headwater cells
// are found. Processing then works back downstream from the headwater cells.
static NumericVector accumulate_impl(const IntegerVector & basin_ids, const IntegerVector & downstream_ids, const NumericVector & flows, AccumulationType acc_type) {
  auto n = basin_ids.size();

  if (downstream_ids.size() != n) {
    stop("Expected %d downstream IDs but got %d", n, downstream_ids.size());
  }

  if (flows.size() != n) {
    stop("Expected %d flows but got %d", n, flows.size());
  }

  std::unordered_map<basin_id, Basin> basins;
  basins.reserve(n);
  std::stack<Basin*> to_process;
  NumericVector results = no_init(n);

  // Construct all basins
  for (auto i = 0; i < n; i++) {
    basins.emplace(std::piecewise_construct,
                   std::forward_as_tuple(basin_ids[i]),
                   std::forward_as_tuple(basin_ids[i], flows[i]));
  }

  // Set references to downstream basins
  for (auto i = 0; i < n; i++) {
    if (downstream_ids[i] > 0) {
      auto downstream_kv = basins.find(downstream_ids[i]);
      if (downstream_kv == basins.end()) {
        stop("Basin %d references downstream basin %d, but it does not exist.",
               basin_ids[i], downstream_ids[i]);
      }

      Basin* downstream = &(downstream_kv->second);
      basins.at(basin_ids[i]).set_downstream(downstream);
    }
  }

  for (auto& kv : basins) {
    Basin& basin = kv.second;
    if (basin.is_mouth_of_river()) {
      to_process.push(&basin);
    } else {
      // Add this basin to the downstream basin's list of
      // upstream basins.
      basin.downstream->add_upstream(&basin);
    }
  }

  while(!to_process.empty()) {
    auto basin = to_process.top();

#if DEBUG
    Rcout << "At " << basin->id << std::endl;
#endif

    if (basin->visited || basin->is_headwater()) {
      to_process.pop();
      basin->flow_out = basin->flow;

      // Add flow from upstream basins
      for (const auto& upstream : basin->upstream) {
        basin->flow_out += upstream->flow_out;
      }

#if DEBUG
     Rcout << " processed " << basin->id << " " << basin->flow_out << std::endl;
#endif
    } else {
      // Queue up the upstream basins for processing
      for (auto& upstream : basin->upstream) {
        to_process.push(upstream);
        upstream->flow_downstream += (basin->flow + basin->flow_downstream);

#if DEBUG
        Rcout << " going upstream to " << upstream->id << std::endl;
#endif
      }
      basin->visited = true;
    }
  }

  std::transform(basin_ids.begin(),
                 basin_ids.end(),
                 results.begin(),
                 [&acc_type, &basins](const basin_id& id) {
                   switch (acc_type) {
                     case AccumulationType::FLOW_DOWNSTREAM:
                       return basins.at(id).flow_downstream;
                     case AccumulationType::FLOW_OUT:
                       return basins.at(id).flow_out;
                   }

		   stop("Unknown accumulation type.");
                 });

  return results;
}

//' Perform a basin-to-basin flow accumulation
//'
//' @param basin_ids       a vector of basin ids
//' @param downstream_ids  a vector of downstream basin ids,
//'                        aligned with the entries in \code{basin_ids}
//' @param flows           a vector of flows generated in each basin,
//'                        aligned with the entries in \code{basin_ids}
//' @return a vector of outlet flows for each basin (including flow generated
//'         within the basin), aligned with the entries in \code{basin_ids}
//' @export
// [[Rcpp::export]]
NumericVector accumulate(const IntegerVector & basin_ids, const IntegerVector & downstream_ids, const NumericVector & flows) {
  return accumulate_impl(basin_ids, downstream_ids, flows, AccumulationType::FLOW_OUT);
}

//' Compute the sum of flow originating in downstream basins
//'
//' @param basin_ids       a vector of basin ids
//' @param downstream_ids  a vector of downstream basin ids,
//'                        aligned with the entries in \code{basin_ids}
//' @param flows           a vector of flows generated in each basin,
//'                        aligned with the entries in \code{basin_ids}
//' @return a vector of downstream flows for each basin (excluding flow generated
//'         within the basin), aligned with the entries in \code{basin_ids}
//' @export
// [[Rcpp::export]]
NumericVector downstream_flow(const IntegerVector & basin_ids, const IntegerVector & downstream_ids, const NumericVector & flows) {
  return accumulate_impl(basin_ids, downstream_ids, flows, AccumulationType::FLOW_DOWNSTREAM);
}
