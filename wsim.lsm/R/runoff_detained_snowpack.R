runoff_detained_snowpack <- function(Ds, Xs, melt_month, z) {
	ifelse(z < 500,
	       ifelse(melt_month == 1,
		      0.1,
		      ifelse(melt_month > 1,
			     0.5,
			     0.0)),
	       ifelse(melt_month == 1,
		      0.1,
		      ifelse(melt_month == 2,
			     0.25,
			     ifelse(melt_month > 2,
				    0.50,
				    0.0)))) * (Ds + Xs)
}
