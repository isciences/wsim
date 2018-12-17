library(wsim.electricity)
library(wsim.distributions)
library(Rcpp)


fig_width <- 5
fig_height <- 3.5

# Hydropower loss risk

svg(filename="hydropower_loss_risk.svg",
    width=fig_width,
    height=fig_height,
    bg='transparent')
par(mar=c(5.1, 4.1, 1, 2.1))

curve(hydropower_loss(x, 1.0, 0.6),
      xlab="blue water / expected blue water",
      ylab="Loss Risk",
      from=1.0,
      to=0.0,
      xlim=c(1, 0))

dev.off()

# Thermoelectric loss risk

svg(filename="thermoelectric_loss_risk.svg",
    width=fig_width,
    height=fig_height,
    bg='transparent')

par(mar=c(5.1, 4.1, 1, 2.1))

curve(water_cooled_loss(x, 10, 40),
      xlab="Total Blue Water Return Period",
      ylab="Loss Risk",
      from=0,
      to=80
)

curve(water_cooled_loss(x, 30, 60),
      from=0,
      to=80,
      lty='dotted',
      add=TRUE)

dev.off()

svg(filename="thermoelectric_loss_onset.svg",
    width=fig_width,
    height=fig_height,
    bg='transparent')
par(mar=c(5.1, 4.1, 1, 2.1))

curve(water_cooled_loss_onset(x),
      xlab="Baseline Water Stress",
      ylab="Onset of Loss (years)",
      from=0,
      to=1)

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
curve(temperature_loss(To=x,
		       To_rp=rp(x, fit),
		       Tc=-10,
		       Tc_rp=-30,
		       Tbas=x,
		       Treg=32,
		       Tdiff=8),
      xlab="Air Temperature [degrees C]",
      ylab="Loss Risk",
      from=-30,
      to=50,
      n=200)

curve(temperature_loss(To=x,
		       eff=0.005,
		       Teff=20),
      from=-30,
      to=50,
      n=200,
      lty='dotted',
      add=TRUE)

dev.off()

