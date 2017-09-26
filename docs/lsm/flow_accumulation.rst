Flow Accumulation
*****************

WSIM uses a traditional pixel-to-pixel based flow accumulation algorithm  to compute total blue water.
This algorithm uses an eight-neighbor flow direction grid that identifies the downstream grid cell for each grid cell (Vörösmarty, 2010).
This algorithm has two major benefits:
it is well known and easy to implement,
and it produces results that highlight the specific paths of the stream network during periods of extreme anomalies. 

However, these algorithms also have known limitations relative to WSIM requirements.
First, most implementations have difficulty with the notion of negative net runoff values which can arise when total consumptive withdrawals exceed local runoff.
Second, they place a very high and unrealistic requirement on the spatial precision of methods used to disaggregate human withdrawals because they force the estimates to be precise to grid cell resolution.
Third, surface water surplus or deficit tends to have impacts that extend beyond an individual pixel as opposed to impacting just those people who live directly within the pixel.
Given these limitations, we only use pixel-to-pixel based flow accumulation to compute total blue water (:math:`B_t`), which does not account for withdrawals by humans.

