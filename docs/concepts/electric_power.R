library(wsim.electricity)
library(wsim.distributions)
library(Rcpp)

fig_width <- 5
fig_height <- 3.5

svg(filename="hydropower_loss_risk.svg",
    width=fig_width,
    height=fig_height,
    bg='transparent')
par(mar=c(5.1, 4.1, 1, 2.1))

curve(hydropower_loss(x, 1.0, 0.6),
      xlab="blue water / expected blue water",
      ylab="Loss Risk",
      from=0.0,
      to=1.0)

dev.off()

# February temperature distribution (gev) for a pixel in VT
fit <- c(location=-8.2580904, scale=2.5978118, shape=0.3449418)

rp <- function(x, fit) {
  sa2rp(standard_anomaly('gev', fit, x))
}

svg(filename="air_temperature_loss.svg",
    width=fig_width,
    height=fig_height,
    bg='transparent')
par(mar=c(5.1, 4.1, 1, 2.1))
curve(temperature_loss(x,
		       rp(x, fit),
		       Tc=-10,
		       Tc_rp=-30,
		       Teff=20,
		       Treg=32,
		       Tdiff=8),
      xlab="Air Temperature [degrees C]",
      ylab="Loss Risk",
      from=-30,
      to=50,
      n=200)

curve(temperature_loss(x,
		       rp(x, fit),
		       Tc=-10,
		       Tc_rp=-30,
		       eff=0.007,
		       Teff=20),
      from=-30,
      to=50,
      n=200,
      lty='dotted',
      add=TRUE)

curve(temperature_loss(x,
		       rp(x, fit),
		       Tc=-10,
		       Tc_rp=-30,
		       eff=0.003,
		       Teff=20),
      from=-30,
      to=50,
      n=200,
      lty='dotted',
      add=TRUE)

dev.off()

