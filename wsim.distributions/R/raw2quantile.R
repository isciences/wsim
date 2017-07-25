raw2quantile <- function(forecast, GEV) {
# raw2quantile:  Calculates the quantile of the raw forecast relative to the retrospective forecasts

    # forecast is a rasterStack of scientific unit values
    # GEV is a rasterStack of GEV parameters: xi, alpha, kappa
    # Returns a rasterLayer of quantiles based on the GEV parameters

	forecast.vals <- getValues(forecast)
	gev.vals <- getValues(GEV)

	qvals <- vector(mode = 'numeric', length(forecast.vals))
	for(i in 1:length(forecast.vals)){
		if( any(is.na(gev.vals[i,])) ){ # If any of the fit parameters r NA
			#if(length(unique(retro.values[i,])) > 30){
			#	qvals[i] <- ecdf(retro.values[i,])(forecast.vals[i])
			#}else{
            cat('\t\t\tUsing median in raw2quantile\n')
				qvals[i] <- 0.5 # If not enough unique values, use the median.
			#}
		}else{
			qvals[i] <- lmom::cdfgev(forecast.vals[i], gev.vals[i,])
		}
	}
	quant <- raster(forecast)
	quant <- setValues(quant, qvals)
	#rm(retro.values)
	return(quant)
}

