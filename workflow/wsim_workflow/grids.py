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

import re

class Grid:

    def __init__(self, name: str, xmin: float, ymin: float, xmax: float, ymax: float, nx: int, ny: int):
        self.name = name
        self.xmin = xmin
        self.ymin = ymin
        self.xmax = xmax
        self.ymax = ymax
        self.nx = nx
        self.ny = ny

    def name(self) -> str:
        return self.name

    def dx(self) -> float:
        return (self.xmax - self.xmin) / self.nx

    def dy(self) -> float:
        return (self.ymax - self.ymin) / self.ny

    def gdal_tr(self) -> str:
        return "{:f} {:f}".format(self.dx(), self.dy())

    def gdal_te(self) -> str:
        return "{xmin:f} {ymin:f} {xmax:f} {ymax:f}".format(
            xmin=self.xmin, ymin=self.ymin, xmax=self.xmax, ymax=self.ymax)

    @staticmethod
    def _wgrib_format_number(num):
        return '{:f}'.format(num).rstrip('0').rstrip('.')

    def wgrib_def(self) -> str:
        return '{xmin}:{nx}:{dx} {ymin}:{ny}:{dy}'.format(
            xmin=self._wgrib_format_number(self.xmin + 0.5*self.dx()),
            nx=self._wgrib_format_number(self.nx),
            dx=self._wgrib_format_number(self.dx()),
            ymin=self._wgrib_format_number(self.ymin + 0.5*self.dy()),
            ny=self._wgrib_format_number(self.ny),
            dy=self._wgrib_format_number(self.dy())
        )

GLOBAL_HALF_DEGREE = Grid('global_half_degree', -180, -90, 180, 90, 720, 360)
