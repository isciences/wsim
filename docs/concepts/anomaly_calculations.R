require(lmom)

fig_width <- 5
fig_height <- 3.5

set.seed(123)

nobs <- 60

location <- 50
scale <- 17.8
shape <- -0.3

fit_params <- c(location, scale, shape)

example_prob <- 0.85

# Generate some random observations consistent with this distribution
data <- quagev(runif(nobs), fit_params)

# Plot the observations

svg(filename="anomaly_calculations_obs.svg",
    bg='transparent',
    width=fig_width,
    height=fig_height)
par(mar=c(5.1, 4.1, 1, 2.1))

plot(data,
     pch=16,
     cex=0.8,
     col='#998ec3',
     ylab='Precipitation (mm)',
     xlab='Year')

dev.off()

precip <- quagev(example_prob, fit_params)

# Plot the empirical and generated cdfs

svg(filename="anomaly_calculations_cdfs.svg",
    bg='transparent',
    width=fig_width,
    height=fig_height)
par(mar=c(5.1, 4.1, 1, 2.1))

curve(cdfgev(x, para=fit_params), 
      from=0,
      to=quagev(0.99, fit_params),
      ylab='Cumulative probability',
      xlab='Precipitation (mm)',
      col='#f1a340',
      lwd=2)

arrows(precip, 0, precip, example_prob/2, col='#998ec3', lty='dashed')
segments(precip, example_prob/2, precip, example_prob, col='#998ec3', lty='dashed')
arrows(precip, example_prob, precip/2, example_prob, col='#998ec3', lty='dashed')
segments(precip/2, example_prob, 0, example_prob, col='#998ec3', lty='dashed')

plot(ecdf(data),
     pch='x',
     cex=0.6,
     lwd=0,
     col.01line='transparent',
     add=TRUE)

dev.off()