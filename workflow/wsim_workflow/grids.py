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

    def wgrib_def(self) -> str:
        return "{xmin:f}:{nx:d}:{dx:f} {ymin:f}:{ny:d}:{dy:f}".format(
            xmin=self.xmin,
            nx=self.nx,
            dx=self.dx(),
            ymin=self.ymin,
            ny=self.ny,
            dy=self.dy()
        )

GLOBAL_HALF_DEGREE = Grid('global_half_degree', -180, -90, 180, 90, 720, 360)
