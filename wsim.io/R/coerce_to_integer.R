# Copyright (c) 2018 ISciences, LLC.
# All rights reserved.
#
# WSIM is licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License. You may
# obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

coerce_to_integer <- function(vals) {
  if (is.integer(vals)) {
    return(vals)
  }

  int_vals <- as.integer(vals)
  if (any(vals != int_vals)) {
    stop("Values cannot be coerced to integers")
  }

  return(int_vals)
}
