# Copyright (c) 2022 ISciences, LLC.
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

from .step import Step
from .paths import Vardef, DefaultWorkspace, Static
from .commands import q

from typing import List, Optional, Union


def compute_population_summary(workspace: DefaultWorkspace,
                               static: Static,
                               *,
                               yearmon: str,
                               window: int,
                               target: Optional[str] = None) -> List[Step]:

    composite_fname = workspace.composite_summary_adjusted(yearmon=yearmon, target=target, window=window)

    return [wsim_polygon_summary(
        polygons=static.countries().file,
        values=[Vardef(composite_fname, 'surplus'),
                Vardef(composite_fname, 'deficit@negate').read_as('deficit')],
        weights=static.population_density().read_as('population'),
        append_cols=['GID_0->country_iso', 'NAME_0->country_name'],
        output=workspace.composite_summary_population(yearmon=yearmon, target=target, window=window)
    )]


def wsim_polygon_summary(*,
                         polygons: str,
                         append_cols: List[str],
                         values: List[Union[Vardef, str]],
                         weights: Union[Vardef, str],
                         output: str) -> Step:
    cmd = [
        os.path.join('{BINDIR}', 'wsim_polygon_summary.R')
    ]

    for v in values:
        cmd += ['--values', q(str(v))]

    cmd += [
        '--weights', q(str(weights)),
        '--polygons', polygons,
        '--append-cols', q(','.join(append_cols)),
        '--breaks', q('3,5,10,20,40'),
        '--output', q(output)
    ]

    values = [x if type(x) is str else x.file for x in values]
    weights = weights if type(weights) is str else weights.file

    return Step(
        targets=output,
        dependencies=[polygons, weights] + values,
        commands=[cmd]
    )
