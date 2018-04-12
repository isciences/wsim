require(lmom)

fig_width <- 9
fig_height <- 3.5

# Fits for Chittenden County, VT
# 3-month period ending in September
fit_ws <- c(131.1977, 29.28537, 0.7643901)
fit_petme <- c(0.5859337, 0.9393641, -0.5906514)
fit_bt_ro <- c(369163011, 199855715, -0.06162665)

# Observed values for 3-month period ending in September 2009
ws <- 110.6198
petme <- 4.775393
bt_ro <- 89912448

components <- list(
  list(fit=fit_ws, obs=ws, desc='Soil Moisture (3-month average, mm)'),
  list(fit=fit_petme, obs=petme, desc='Potential - Actual ET (3-month sum, mm)'),
  list(fit=fit_bt_ro, obs=bt_ro, desc='Total Blue Water (3-month sum, mm)')
)

col <- '#998ec3'
lty <- 'dashed'

plotcdf <- function(obs, para, desc, xmin=NULL, xmax=NULL) {
  prob <- cdfgev(obs, para=para)
  if (is.null(xmin)) xmin <- obs * 0.5
  if (is.null(xmax)) xmax <- obs * 1.5
  ymin <- cdfgev(xmin, para=para)

  curve(cdfgev(x, para=para),
        from=xmin,
        to=xmax,
        ylab='Cumulative probability',
        xlab=desc,
        col='#f1a340',
        main=sub(' [(].*', '', desc),
        lwd=2)

  segments(x0=obs, y0=0, y1=prob,
           col=col,
           lty=lty)

  segments(x0=obs, y0=prob, x1=xmin,
           col=col,
           lty=lty)

  # print observed value
  text(obs,
       ymin + 0.1*(prob-ymin),
       sprintf(ifelse(obs > 1000, '%.2e', '%.2f'), obs),
       pos=4)

  # print observed probability
  text(xmin + 0.1*(obs - xmin),
       prob,
       sprintf('%.3f', prob),
       pos=3)

  arrows(x0=obs, y0=0, y1=prob/2, col=col, lty=lty, length=0.1)
  arrows(x0=obs, y0=prob, x1=xmin, col=col, lty=lty, length=0.1)
}

svg(filename='composite_example_cdfs.svg',
    bg='transparent',
    width=fig_width,
    height=fig_height)

par(mfrow=c(1,3),
    mar=c(5,5,2,1))

for (component in components) {
  plotcdf(component$obs, component$fit, component$desc)
}

dev.off()

svg(filename='composite_example_adjusted_cdf.svg',
    bg='transparent',
    width=0.5*fig_width,
    height=fig_height)

plotcdf(-2.21, c(-0.7565543,0.9031551,0.2727567), 'Composite Deficit (as Standard Anomaly)',
        xmin=-2.5, xmax=-2)

dev.off()

#arrows(precip, 0, precip, example_prob/2, col='#998ec3', lty='dashed')
#arrows(precip, example_prob, precip/2, example_prob, col='#998ec3', lty='dashed')
#segments(precip/2, example_prob, 0, example_prob, col='#998ec3', lty='dashed')
