import rasterio
import numpy as np

infile = '/home/dbaston/wise_30sec/wise_30sec_v1.tif'
mode = 2

if mode == 1:
    classes = '/home/dbaston/wise_30sec/wise_tawc_for_pixel_value.csv'
    outfile = '/tmp/wise_30sec_tawc.tif'
if mode == 2:
    classes = '/home/dbaston/wise_30sec/wise_missing_data_for_pixel_value.csv'
    outfile = '/tmp/wise_30sec_tawc_missing.tif'

f = rasterio.open(infile)
fout = rasterio.open(outfile,
                     'w',
                     driver='GTiff',
                     width=f.width,
                     height=f.height,
                     crs=f.crs,
                     transform=f.transform,
                     nodata=np.finfo(np.float32).min,
                     count=1,
                     dtype=rasterio.float32,
                     compress='deflate')

#tawc_dict = {}
with open(classes, 'r') as classfile:
    classfile.readline() # skip header
    max_pixel_value = max( int(line.strip().split(',')[0]) for line in classfile )
    tawc_vals = np.full(1 + max_pixel_value*2, fout.nodata)

    classfile.seek(0)
    classfile.readline() # skip header
    for line in classfile:
        pixel_value, tawc = line.strip().split(',')
        if tawc != 'NA':
            pixel_value = int(pixel_value)
            tawc_vals[pixel_value] = float(tawc)

for i, (_, window) in enumerate(f.block_windows(1)):
    data = f.read(1, window=window)
    if i == 0:
        data_out = np.empty(shape=data.shape, dtype=np.float32)
    slc = tawc_vals[data[0, :]]
    data_out[0, :] = slc
    #data_out[0, :] = np.fromiter((tawc_dict[px] for px in data[0,:]), np.float32)
    #data = np.fromiter(, rasterio.float32)
    fout.write(data_out, window=window, indexes=1)
    print(i)

# Compute where there is no TAWC value
#~/dev/gdal-2.2.2/swig/python/scripts/gdal_calc.py --calc="A<0" -A /tmp/wise_30sec_tawc.tif --outfile /tmp/junk3.tif --co="COMPRESS=DEFLATE"
# gives 0 where TAWC defined, 1 where TAWC undefined, NODATA in oceans

# RESAMPLE WITH THIS
# gdal_translate -of GTiff -r average -tr 0.5 0.5 -projwin -180 90 180 -90 /tmp/fizzo2.tif /tmp/fizz2_05deg.tif
