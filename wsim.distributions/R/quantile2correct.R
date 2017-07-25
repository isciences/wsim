quantile2correct <-  function(quant, obsGEV, forecast){
# quantile2correct: Calculates the new forecast from the quantile

	qvals <- getValues(quant)  # 0.5 degree
	ogev.vals <- getValues(obsGEV) # 0.5 degree Result is a ncells X 3 matrix.
	#rgev.vals <- getValues(retroGEV) # 0.5 degree
	forecast.vals <- getValues(forecast) # 0.5 degree

	# cvals aka "corrected values"
	cvals <- vector('numeric', length(qvals))
	for(i in 1:length(qvals)) {
		if(is.na(qvals[i])){
			cvals[i] <- NA # If quantile is missing, use value in rgev.vals
		}else{
			if(is.na(ogev.vals[i,1])){
				cvals[i] <- NA	# if obsGEV parameter 1 is missing, use NA (ocean).
			}else{
				if(is.na(ogev.vals[i,2])){
					# if obsGEV parameter 2 is missing, can't use quagev because no cdf estimatedd
					# instead, use the value stored in obsGEV parameter 1 -- that's the median of observed
					# See obs.cdf.R for details.
					cvals[i] <- ogev.vals[i,1]
				}else{
					# Finally, everything is there that is supposed to be, and we can use quagev
					# with the obsGEV parameters to estimate corrected values.
					cvals[i] <- lmom::quagev(qvals[i], ogev.vals[i,])
				}
			}
		}
	}
	corrected <- raster(quant)
	corrected <- setValues(corrected, cvals)

	return(corrected)
}
