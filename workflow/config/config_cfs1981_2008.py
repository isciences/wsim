from config_cfs import CFSConfig
from config_cpc import CPCConfig

cpc = CPCConfig('', '')

class CFSConfig1981_2008(CFSConfig):
    def historical_years(self):
        return cpc.historical_years()

    def result_fit_years(self):
        return cpc.result_fit_years()

config = CFSConfig1981_2008