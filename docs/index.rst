WSIM documentation
================================

The Water Security Indicator Model (WSIM) is an open-source project developed by ISciences, LLC.

WSIM identifies locations on Earth’s terrestrial surface that are experiencing stress due to deficits or surpluses of fresh water that may impact normal functioning of society. This is accomplished by monitoring surface water dynamics, estimating the surface volume of water, and determining departure from normal conditions.  These are then evaluated in context of agricultural, industrial and domestic needs; assessing the sensitivity of given places to such stress; and evaluating the capacity of the people in those places to respond.

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

.. toctree::
   :maxdepth: 2
   :glob:
   :caption: Contents:

   obtaining
   scripts/index
   lsm/index
   r_packages/index
   development
