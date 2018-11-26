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

from ..step import Step
from typing import List


def global_flow_direction(filename: str, resolution: float) -> List[Step]:
    if resolution == 2:
        res_txt = '2'
    elif resolution == 1:
        res_txt = '1'
    elif resolution == 1.0/2:
        res_txt = 'half'
    elif resolution == 1.0/4:
        res_txt = 'qd'
    elif resolution == 1.0/8:
        res_txt = '8th'
    elif resolution == 1.0/10:
        res_txt = '10th'
    elif resolution == 1.0/12:
        res_txt = '12th'
    elif resolution == 1.0/16:
        res_txt = '16th'
    else:
        raise ValueError('The DRT flow direction dataset is not available in {}-degree resolution.')

    url = 'http://files.ntsg.umt.edu/data/DRT/upscaled_global_hydrography/by_HydroSHEDS_Hydro1k/flow_direction/DRT_{}_FDR_globe.asc'.format(res_txt)  # noqa

    return [
        # Download flow grid
        Step(
            targets=filename,
            dependencies=[],
            commands=[
                ['wget', '-O', filename, url]
            ]
        )
    ]
