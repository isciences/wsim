# Copyright (c) 2018-2019 ISciences, LLC.
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
from wsim_workflow.grids import Grid
from wsim_workflow.data_sources import \
    gadm,\
    gmted,\
    gppd,\
    gpw,\
    grand,\
    hydrobasins,\
    isric,\
    mirca2000,\
    spam2010,\
    stn30


class DefaultStatic(paths.Static, paths.ElectricityStatic, paths.AgricultureStatic):
    def __init__(self, source: str, grid: Grid):
        super(DefaultStatic, self).__init__(source)
        self.grid = grid

        self.gpw_year = 2020
        self.gpw_res = '2pt5_min'

    def global_prep_steps(self):
        return \
            self.prepare_admin_boundaries() + \
            self.prepare_ag_calendars() + \
            self.prepare_ag_production() + \
            self.prepare_basins() + \
            self.prepare_dams() + \
            self.prepare_elevation() + \
            self.prepare_flow_direction() + \
            self.prepare_population_density(self.gpw_year, self.gpw_res) + \
            self.prepare_power_plants() + \
            self.prepare_soil_water_capacity()

    def prepare_admin_boundaries(self):
        return gadm.prepare_admin_boundaries(source_dir=self.source, levels=[0, 1])

    def prepare_soil_water_capacity(self):
        return isric.global_tawc(source_dir=self.source, filename=self.wc().file, grid=self.grid)

    def prepare_flow_direction(self):
        assert (self.grid.dx() / 0.5) == int(self.grid.dx() / 0.5),\
            "Analysis grid resolution must be integer multiple of flow direction grid resolution"
        return stn30.global_flow_direction(source_dir=self.source, filename=self.flowdir().file, resolution=0.5)

    def prepare_elevation(self):
        return gmted.global_elevation(source_dir=self.source, filename=self.elevation().file, grid=self.grid)

    def prepare_population_density(self, year, res):
        return gpw.download(self.source, year, res)

    def prepare_power_plants(self):
        return gppd.power_plant_database(source_dir=self.source)

    def prepare_dams(self):
        return grand.download_grand(source_dir=self.source)

    def prepare_basins(self):
        return hydrobasins.basins(source_dir=self.source, filename=self.basins().file, level=7) + \
               hydrobasins.downstream_ids(source_dir=self.source,
                                          basins_file=self.basins().file,
                                          ids_file=self.basin_downstream().file)

    def prepare_ag_calendars(self):
        return mirca2000.crop_calendars(source_dir=self.source)

    def prepare_ag_production(self):
        return spam2010.production(source_dir=self.source) + \
               spam2010.allocate_spam_production(spam_zip=spam2010.spam_zip(self.source),
                                                 method=paths.Method.IRRIGATED,
                                                 area_fractions=self.crop_calendar(method=paths.Method.IRRIGATED),
                                                 output=self.production(method=paths.Method.IRRIGATED).file) + \
               spam2010.allocate_spam_production(spam_zip=spam2010.spam_zip(self.source),
                                                 method=paths.Method.RAINFED,
                                                 area_fractions=self.crop_calendar(method=paths.Method.RAINFED),
                                                 output=self.production(method=paths.Method.RAINFED).file)

    # Static inputs
    def wc(self) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'ISRIC', 'wise_{}_v1_tawc.tif'.format(self.grid.name)), '1')

    def flowdir(self) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'STN_30', 'g_network.asc'), '1')

    def elevation(self) -> paths.Vardef:
        return paths.Vardef(gmted.filename(self.source, self.grid.name), '1')

    def population_density(self) -> paths.Vardef:
        return paths.Vardef(gpw.population_density(self.source, self.gpw_year, self.gpw_res), '1')

    def basins(self) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'HydroBASINS', 'basins_lev07.shp'), None)

    def basin_downstream(self) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'HydroBASINS', 'basins_lev07_downstream.nc'), 'next_down')

    def dam_locations(self) -> paths.Vardef:
        return paths.Vardef(grand.dam_locations(self.source), None)

    def water_stress(self) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'Aqueduct', 'aqueduct_baseline_water_stress.tif'), '1')

    def power_plants(self) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'GPPD', 'gppd_inferred_cooling.nc'), None)

    def countries(self) -> paths.Vardef:
        return paths.Vardef(gadm.admin_boundaries(self.source, 0), None)

    def provinces(self) -> paths.Vardef:
        return paths.Vardef(gadm.admin_boundaries(self.source, 1), None)

    def crop_calendar(self, method: paths.Method) -> str:
        return os.path.join(self.source, 'MIRCA2000', 'crop_calendar_{}.nc'.format(method.value))

    def production(self, method: paths.Method) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, spam2010.SUBDIR, 'production_{}.nc'.format(method.value)),
                            'production')

    def ag_yield_anomaly_model(self, model_name: str) -> str:
        return os.path.join(self.source, 'ag_models', 'r7_{}.rds'.format(model_name))
