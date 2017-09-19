import rasterio
import rasterio.mask
import rasterio.warp
import fiona
import numpy
import netCDF4
import datetime
import contextlib
from functools import reduce

FLOAT_NODATA = -3.4e+38
BYTE_NODATA = -127

categories = [
    { "value" :  0,  "type" : "Water",   "min" : None, "max" : None,       "color" : [217, 244, 255] },
    { "value" :  1,  "type" : "Surplus", "min" : 3,  "max" : 5,            "color" : [206, 255, 173] },
    { "value" :  2,  "type" : "Surplus", "min" : 5,  "max" : 10,           "color" : [0,   243, 181] },
    { "value" :  3,  "type" : "Surplus", "min" : 10, "max" : 20,           "color" : [0,   207, 206] },
    { "value" :  4,  "type" : "Surplus", "min" : 20, "max" : 40,           "color" : [0,   154, 222] },
    { "value" :  5,  "type" : "Surplus", "min" : 40, "max" : float('inf'), "color" : [0,   69,  181] },
    { "value" :  6,  "type" : "Deficit", "min" : 3,  "max" : 5,            "color" : [255, 237, 163] },
    { "value" :  7,  "type" : "Deficit", "min" : 5,  "max" : 10,           "color" : [255, 199, 84 ] },
    { "value" :  8,  "type" : "Deficit", "min" : 10, "max" : 20,           "color" : [255, 141, 67 ] },
    { "value" :  9,  "type" : "Deficit", "min" : 20, "max" : 40,           "color" : [212, 65,  53 ] },
    { "value" :  10, "type" : "Deficit", "min" : 40, "max" : float('inf'), "color" : [155, 0,   57 ] },
    { "value" :  11, "type" : "Both",    "min" : 3,  "max" : 5,            "color" : [255, 214, 233] },
    { "value" :  12, "type" : "Both",    "min" : 5,  "max" : 10,           "color" : [255, 179, 230] },
    { "value" :  13, "type" : "Both",    "min" : 10, "max" : 20,           "color" : [253, 128, 210] },
    { "value" :  14, "type" : "Both",    "min" : 20, "max" : 40,           "color" : [193, 63,  178] },
    { "value" :  15, "type" : "Both",    "min" : 40, "max" : float('inf'), "color" : [137, 0,   155] },
]
cat_vals = [cat["value"] for cat in categories]

def label(cat):
    """
    Generate a label for a given category definition
    """

    if cat["max"] == float('inf'):
        range_text = ">" + str(cat["max"])
    else:
        range_text = str(cat["min"]) + "-" + str(cat["max"])

    return cat["type"] + '_' + range_text

def rgb_to_hex(r, g, b):
    return '#' + ''.join('%02x' % v for v in (r,g,b)).upper()

def classify(arr, calamity, cats):
    """
    Produce a byte array whose values are assigned according to the
    supplied category definitions.

    :param arr: Array to classify
    :param calamity: "Surplus", "Deficit", or "Both"
    :param cats: Category definition list
    :return: Byte array as defined above
    """
    classified = numpy.ma.masked_all(arr.shape, numpy.int8)

    for cat in cats:
        if cat['type'].lower() == calamity.lower():
            print('Processing', cat['type'], cat['min'], cat['max'])
            # Assigning values will implicity unmask these cells
            classified[(numpy.ma.logical_and(arr >= cat['min'], arr < cat['max'])).filled(False)] = cat['value']

    return classified

def merge(a, b):
    """
    Merge matrix b into matrix a, wherever b is defined.
    """
    a = a.copy()
    a[~b.mask] = b[~b.mask]
    return a
    #b = b.copy()
    #b[~a.mask] = a[~a.mask]
    #return b

def centers(begin, end, n):
    """
    Compute the centers of n cells between begin and end.
    """
    d = (end - begin) / n
    return numpy.linspace(begin + d/2, end - d/2, num=n)

args = lambda x: None # create dummy object
args.surplus = '/home/dbaston/composite_examples/surplus_trgt201701.img'
args.deficit = '/home/dbaston/composite_examples/deficit_trgt201701.img'
args.both = '/home/dbaston/composite_examples/both_t3_trgt201701.img'
args.output = '/tmp/hotspots.nc'
args.water = ['/home/dbaston/Downloads/ne_110m_lakes.shp', '/home/dbaston/Downloads/ne_110m_ocean.shp']

def read_masked(fname, expected_shape = None, expected_bounds = None, scale = 1.0):
    """
    Read the first band of a file into a masked array.  Optionally
    check the shape and bounds of the file against expected values, and
    throw an exception if the values differ.
    """
    with rasterio.open(fname) as rast:
        if expected_shape and rast.shape != expected_shape:
            raise "Resolution of " + fname + " does not match expected value"
        if expected_bounds and rast.bounds != expected_bounds:
            raise "Bounds of " + fname + " do not match expected value"

        vals = rast.read(1, masked=True)
        if scale == 1.0:
            return vals
        else:
            return resample(vals, rast.crs, rast.transform, scale, rast.nodata)

def scaled_shape(shape, scale):
    return tuple(round(dim*scale) for dim in shape)

def scaled_transform(aff, scale):
    return rasterio.Affine(aff.a / scale,
                           aff.b,
                           aff.c,
                           aff.d,
                           aff.e / scale,
                           aff.f)

def resample(arr, crs, aff, scale, nodata=-9999):
    dest = numpy.full(shape=scaled_shape(arr.shape, scale),
                      fill_value=-9999,
                      dtype=arr.dtype)

    rasterio.warp.reproject(numpy.ma.filled(arr, nodata),
                            dest,
                            src_transform=aff,
                            dst_transform=scaled_transform(aff, scale),
                            src_nodata=nodata,
                            dst_nodata=nodata,
                            src_crs=crs,
                            dst_crs=crs,
                            resample=rasterio.warp.Resampling.bilinear)

    return numpy.ma.masked_equal(dest, nodata)

def read_shape_mask(raster_shape, raster_affine, fname):
    """
    Produce a boolean ndarray whose values are True when the pixel is
    within a polygon stored in a supplied shapefile.
    """
    with fiona.open(fname, "r") as mask_shapefile:
        shapes = [feature["geometry"] for feature in mask_shapefile]

    return rasterio.mask.geometry_mask(shapes, raster_shape, raster_affine, invert=True)

def read_shapefiles_as_value(files, value, shape, affine):
    """
    Read a list of shapefiles containing polygons, and return a masked
    byte ndarray with pixels set to `value` when that pixel is within a
    polygon.  Refer to the `rasterio` library for a definition of
    "within-ness".

    :param files: A list of filenames for polygonal shapefiles
    :param value: Numeric value to be set when a pixel is covered by a polygon
    :param shape: Shape of resultant ndarray
    :param affine: Affine transformation matrix from a raster to which
                   resultant array should align
    :return: A masked byte array whose values are either `value`, or masked.
    """
    shape_mask = reduce(numpy.logical_or, (read_shape_mask(shape, affine, f) for f in files))
    return numpy.ma.masked_where(~shape_mask, numpy.full(shape, value, dtype=numpy.byte))

@contextlib.contextmanager
def cdf_output(fname, shape, bounds):
    nlat, nlon = shape
    minlon, minlat, maxlon, maxlat = bounds

    output = netCDF4.Dataset(fname, "w", format="NETCDF4_CLASSIC")

    output.date_modified = datetime.datetime.now().strftime("%Y%m%d")

    output.createDimension("lat", size=nlat)
    output.createDimension("lon", size=nlon)

    latitudes = output.createVariable('lat', numpy.float32, dimensions=("lat", ))
    latitudes.units = "degrees_north"
    latitudes[:] = numpy.flipud(centers(minlat, maxlat, nlat))

    longitudes = output.createVariable('lon', numpy.float32, dimensions=("lon", ))
    longitudes.units = "degrees_east"
    longitudes[:] = centers(minlon, maxlon, nlon)

    yield output
    output.close()

def main():
    scale = 4.0

    with rasterio.open(args.surplus) as rast:
        shape = rast.shape
        bounds = rast.bounds
        affine = rast.transform

    surplus, deficit, both = [read_masked(f, expected_shape=shape, expected_bounds=bounds, scale=scale)
                              for f in (args.surplus, args.deficit, args.both)]

    # Derive classified layers from our raw inputs
    surplus_class = classify(surplus, "surplus", categories)
    deficit_class = classify(-deficit, "deficit", categories)
    both_class = classify(both, "both", categories)

    water_code = [cat["value"] for cat in categories if cat["type"] == "Water"][0]
    water_class = read_shapefiles_as_value(args.water,
                                           water_code,
                                           scaled_shape(shape, scale),
                                           scaled_transform(affine, scale))

    # Merge multiple classification layers into a single "hotspot" layer, with layers on
    # the right superseding layers on the left
    hotspots = reduce(merge, [surplus_class, deficit_class, both_class, water_class])

    with cdf_output(args.output, scaled_shape(shape, scale), bounds) as output:
        surplus_var = output.createVariable("surplus",  numpy.float32, dimensions=("lat", "lon"), fill_value=FLOAT_NODATA)
        surplus_var[:] = surplus.filled(FLOAT_NODATA)
        surplus_var.long_name = "Surplus Index"

        deficit_var = output.createVariable("deficit",  numpy.float32, dimensions=("lat", "lon"), fill_value=FLOAT_NODATA)
        deficit_var[:] = deficit.filled(FLOAT_NODATA)
        deficit_var.long_name = "Deficit Index"

        both_var = output.createVariable("both", numpy.float32, dimensions=("lat", "lon"), fill_value=FLOAT_NODATA)
        both_var[:] = both.filled(FLOAT_NODATA)
        both_var.long_name = "Combined Deficit & Surplus Index"

        category_var = output.createVariable("category", numpy.byte,  dimensions=("lat", "lon"), fill_value=BYTE_NODATA)
        category_var[:] = hotspots.filled(BYTE_NODATA)
        category_var.long_name = "Hotspot Classification"

        category_var.flag_values = ", ".join([str(cat["value"]) for cat in categories])
        category_var.flag_meanings = ", ".join([label(cat) for cat in categories])
        category_var.flag_colors = ", ".join([rgb_to_hex(*cat["color"]) for cat in categories])
        category_var.valid_range = [min(cat_vals), max(cat_vals)]

if True or __name__ == "__main__":
    main()

