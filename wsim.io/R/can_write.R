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

#' Determine if a file can be opened for writing
#'
#' If the file exists, check if we have write
#' permissions on it.
#'
#' If the file does not exist, try creating a file
#' of that name, and then remove it.
#'
#' @param filename filename to test for write access
#' @return TRUE if the file can be opened for writing,
#'         FALSE otherwise
#' @export
can_write <- function(filename) {
  if (file.exists(filename)) {
    # File exists, can we write to it?
    return(unname(file.access(filename, mode=2)) == 0)
  } else {
    tryCatch({
      if(!file.create(filename, showWarnings=FALSE)) {
        return(FALSE)
      }
      while(!file.exists(filename)) {
        Sys.sleep(0.005)
      }
      file.remove(filename)
      return(TRUE);
    }, error=function() {
      return(FALSE);
    })
  }
}
