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

#' Get the command line string used to execute the current program
get_command <- function() {
  raw_args <- commandArgs(trailingOnly=FALSE)

  args <- as.character(c())
  cmd <- ''

  for (i in 1:length(raw_args)) {
    if (startsWith(raw_args[i], '--file=')) {
      cmd <- sub('--file=', '', raw_args[i], fixed=TRUE)
      break
    }
  }

  for (i in 1:length(raw_args)) {
    if (raw_args[i] == '--args') {
      args <- raw_args[-(1:i)]
      break
    }
  }

  return(paste(c(cmd, args), collapse=' '))
}
