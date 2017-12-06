import rasterio
import numpy as np

infile = '/tmp/wise_30sec_tawc.tif'
outfile = '/tmp/noway.tif'

def create_mask_for_fillnodata(infile, outfile):
    # Read a raster and write a raster whose values are:
    # 1 if the input is NODATA, or positive
    # 0 if the input data is zero or negative
    with rasterio.open(infile) as f, \
         rasterio.open(outfile,
                         'w',
                         driver='GTiff',
                         width=f.width,
                         height=f.height,
                         crs=f.crs,
                         transform=f.transform,
                         count=1,
                         dtype=rasterio.uint8,
                         compress='deflate') as fout:

        for (_, window) in f.block_windows(1):
            data = f.read(1, window=window, masked=True)
            data_out = np.ones(shape=data.shape, dtype=np.uint8)
            data_out[np.logical_and(np.logical_not(data.mask), data < 0)] = 0
            fout.write(data_out, window=window, indexes=1)

def mask_less_than_zero(infile, outfile):
    # Read a raster and set values less than zero to NODATA

    with rasterio.open(infile) as f, \
         rasterio.open(outfile,
                       'w',
                       driver='GTiff',
                       width=f.width,
                       height=f.height,
                       crs=f.crs,
                       transform=f.transform,
                       count=1,
                       dtype=f.dtypes[0],
                       nodata=f.nodata,
                       compress='deflate') as fout:

        for (_, window) in f.block_windows(1):
            #data = f.read(1, window=window, masked=True)
            data = f.read(1, window=window)
            data[data < 0] = f.nodata
            #data.mask[data < 0] = True
            #data[data < 0] = fout.nodata
            fout.write(data, window=window, indexes=1)

mask_less_than_zero('/tmp/britain_tawc.tif', '/tmp/britain_tawc_defined.tif')
