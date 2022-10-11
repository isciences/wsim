# Copyright (c) 2021-2022 ISciences, LLC.
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

from wsim_workflow.data_sources import gadm, ntsg_drt, gpw
from wsim_workflow.paths import Vardef
from wsim_workflow.step import Step

from .default_static import DefaultStatic

from typing import List


class ERA5Static(DefaultStatic):

    def __init__(self, source: str, grid):
        super(ERA5Static, self).__init__(source, grid)

    def prepare_flow_direction(self):
        return ntsg_drt.global_flow_direction(self.flowdir().file, 1.0/8)

    def prepare_admin_boundaries(self) -> List[Step]:
        steps = gadm.prepare_admin_boundaries(self.source, [0, 1])
        for level in [0, 1]:
            target = self.countries().file if level == 0 else self.provinces().file
            steps.append(
               Step(
                   targets=target,
                   dependencies=gadm.admin_boundaries(self.source, level),
                   commands=[
                       [
                           os.path.join('{BINDIR}', 'utils', 'era5', 'shift_polygons_to_era5.R'),
                           '--input', gadm.admin_boundaries(self.source, level),
                           '--output', target
                       ]
                   ]
               ))
        return steps

    def prepare_population_density(self, gpw_year: int, gpw_res: str) -> List[Step]:
        steps = super().prepare_population_density(gpw_year, gpw_res)

        infile = super().population_density().file
        outfile = self.population_density().file

        steps.append(Step(
            targets=outfile,
            dependencies=infile,
            commands=[
                [
                    os.path.join('{BINDIR}', 'utils', 'era5', 'shift_gpw_to_era5.sh'),
                    infile, outfile
                ]
            ]
        ))

        return steps

    def population_density(self) -> Vardef:
        standard = super().population_density()
        root, ext = os.path.splitext(standard.file)
        root = root + '_179875_180125'
        return Vardef(root + ext, standard.var)

    def countries(self) -> Vardef:
        return Vardef(os.path.join(self.source, gadm.SUBDIR, 'gadm36_level_0_179875_180125.shp'), None)

    def provinces(self) -> Vardef:
        return Vardef(os.path.join(self.source, gadm.SUBDIR, 'gadm36_level_1_179875_180125.shp'), None)

    def flowdir(self) -> Vardef:
        return Vardef(os.path.join(self.source, ntsg_drt.SUBDIR, ntsg_drt.filename(1.0/8)), '1')
