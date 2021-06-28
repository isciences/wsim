# Copyright (c) 2021 ISciences, LLC.
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

import os

from wsim_workflow import paths

from .default_static import DefaultStatic
from wsim_workflow.data_sources import ntsg_drt


class ERA5Static(DefaultStatic):

    def __init__(self, source: str, grid):
        super(ERA5Static, self).__init__(source, grid)

    def prepare_flow_direction(self):
        return ntsg_drt.global_flow_direction(self.flowdir().file, 1.0/8)

    def flowdir(self) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, ntsg_drt.SUBDIR, ntsg_drt.filename(1.0/8)), '1')
