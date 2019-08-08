
from config_cfs import CFSConfig

class CFSConfigFast(CFSConfig):
    @staticmethod
    def integration_windows() -> List[int]:
        return [3, 12]

    def forecast_ensemble_members(self, yearmon, *, lag_hours: Optional[int] = None):
        return CFSConfig.forecast_ensemble_members(self, yearmon, lag_hours=lag_hours)[:3]
