WSIM - Water Security Indicator Model
=====================================

The Water Security Indicator Model (WSIM) is an open-source project developed by ISciences, LLC.

WSIM identifies locations on Earth’s terrestrial surface that are currently or forecast to be experiencing deficits or surpluses of fresh water.
It operates under the premise that populations are adapted to their local climate and can maintain their activities (agriculture, municipal services, etc.) within the anticipated variations of this climate.
However, stresses are created when conditions vary well beyond these historically-derived expectations, forcing affected populations to react.
These reactions have the potential to induce water disputes, infectious disease outbreaks, agricultural shortfalls, electricity shortages, population displacements, or political instability.

The premise that populations react to *locally unusual* conditions leads WSIM to characterize water stresses in terms of anomalies -- the difference between the actual and expected conditions expressed in a manner that captures the rarity of the event.

This is accomplished by:

1. Modeling a suite of indicator quantities: variables such as evapotranspiration, soil moisture, or runoff.
2. Characterizing the historical variability in these indicators throughout the globe (or region of interest) using statistical distributions.
3. Evaluating current and predicted future values of these indicators in terms of their historical variability.
4. Summarizing individual indicators in terms of composite "water surplus" and "water deficit" indices that provide a meaningful overview of potential stresses experienced by a population.

These composite indices can be used to generate global "hot spot" maps that provide the ability to identify, at subnational scales, emerging water issues that deserve a more detailed analysis.

An example hotspot map is displayed below.

.. _example-global-hotspot:

.. raw:: html

  <div style="width:100%;height:20em;margin-bottom:2em">
		<div id="map" style="width:80%;height:100%;display:inline-block">
			<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/ol3/4.3.3/ol.css" />
			<script src="https://cdnjs.cloudflare.com/ajax/libs/ol3/4.3.3/ol.js"></script>
			<script>
  var map = new ol.Map({
  layers: [
  	new ol.layer.Tile({
  		source: new ol.source.XYZ({
  				url: "https://cartodb-basemaps-{a-d}.global.ssl.fastly.net/light_nolabels/{z}/{x}/{y}.png"
  			}),
  	}),
  	new ol.layer.Image({
  		source: new ol.source.ImageStatic({
  		url: '_static/test.png',
  		projection : 'EPSG:4326',
  		imageExtent: [-180, -90, 180, 90],
  		wrapx: true
  		}),
  		opacity:0.7
  	}),
  	new ol.layer.Tile({
  		source: new ol.source.XYZ({
  				url: "https://cartodb-basemaps-{a-d}.global.ssl.fastly.net/light_only_labels/{z}/{x}/{y}.png"
  			}),
  	}),
  	],
  target: "map",
  view: new ol.View({
  		projection: 'EPSG:3857',
                //extent: [-180, -90, 180, 90],
  		center: ol.proj.fromLonLat([0, 0]),
  		zoom: 1 
  		})
  });
  			</script>
  		</div>
  		<div style="width:15%;height:100%;display:inline-block;vertical-align:top">
  			<img src="_static/legend.png" style="vertical-align:middle" />
  		</div>
  	</div>

.. note::

  WSIM is designed to produce regular reports with global coverage at a minimal lag relative to the release of observational and forecast temperature and precipitation data used to drive the core model.
  This requirement leads to the use of simple models within the core of WSIM, but does not preclude the use of WSIM components with output of more complex models that are external to WSIM.
  In fact, WSIM's workflow module provides an example integration of WSIM analytical tools with outputs from the Noah land surface model, run by the Global Land Data Assimilation System (GLDAS).

Contributors
^^^^^^^^^^^^

.. image:: https://static1.squarespace.com/static/551e8d99e4b0751e1a311984/t/5527dee4e4b06a882556fe4f/1518717771310/?format=1500w
   :target: https://www.isciences.com

WSIM is developed by `ISciences, LLC <https://www.isciences.com>`_.

.. image:: http://www.federalsolutions.com/uploads/2/5/2/6/25268217/8714808.jpg?128
   :target: https://www.erdc.usace.army.mil

The U.S. Army Engineer Research and Development Center (`ERDC <https://www.erdc.usace.army.mil/>`_) sponsors development of WSIM.

.. toctree::
   :maxdepth: 2
   :glob:
   :caption: Contents:

   quick_start
   concepts/index
   obtaining
   working/index
   development
   references

