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


from .config_era5_cfsv2 import ERA5CFSv2Config
from .test_config_cfs import TestCFSConfig


class TestERA5CFSv2Config(TestCFSConfig):
    @classmethod
    def setUpClass(cls):
        #  create a shared config that can be used for multiple tests
        cls.config = ERA5CFSv2Config(cls.source, cls.derived)

        # create a shared dictionary for generated steps that can be used for multiple tests
        cls.steps = {}
