from typing import List, Optional

from config_cfs import CFSConfig
from wsim_workflow import dates


class CFSConfigFast(CFSConfig):
    # Skip 6-month, >12-month integration periods:
    @staticmethod
    def integration_windows() -> List[int]:
        return [3, 12]

    # Use only the first 3 forecast ensemble members:
    def forecast_ensemble_members(self, yearmon, *, lag_hours: Optional[int] = None):
        return CFSConfig.forecast_ensemble_members(self, yearmon, lag_hours=lag_hours)[:2]

    # Forecast out only 3 months instead of 9:
    def forecast_targets(self, yearmon):
        return dates.get_next_yearmons(yearmon, 3)


config = CFSConfigFast