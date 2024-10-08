#!/usr/bin/env python3

from netCDF4 import Dataset
import copy
import sys

# variables to rename { src : dst }
# dst = None deletes a variable
names = { 'valid_time' : 'time', 'number': None }

# destination variable type overrides
types = { 'time' : "float64" , 'expver' : 'int8' }

def main(args):

    _, src_fname, dst_fname = args

    remap_era5(src_fname, dst_fname)


# change some variable names / data types in ERA5 netCDF files so that
# files downloaded from CDS after September 2024 are more similar to
# those downloaded previously
def remap_era5(src_fname, dst_fname, *, attrs = None):

    # code below adapted from https://stackoverflow.com/a/49592545/2171894
    with Dataset(src_fname, "r") as src, Dataset(dst_fname, "w", format="NETCDF4_CLASSIC") as dst:

        # copy global attributes all at once via dictionary
        dst.setncatts(src.__dict__)

        # copy dimensions
        for src_name, dimension in src.dimensions.items():
            dst_name = names.get(src_name, src_name)
            if dst_name:
                dst.createDimension(dst_name, (len(dimension) if not dimension.isunlimited() else None))

        # copy file data
        for src_name, variable in src.variables.items():
            dst_name = names.get(src_name, src_name)

            if dst_name:
                dimensions = tuple(names.get(d, d) for d in variable.dimensions)

                dtype = types.get(dst_name, variable.datatype)

                chunking = variable.chunking()
                if chunking == "contiguous":
                    chunking = None
                else:
                    chunking = [ src.dimensions[dim].size for dim in variable.dimensions ]
                    chunking[0] = 1

                x = dst.createVariable(dst_name,
                        dtype,
                        dimensions,
                        fill_value = variable.__dict__.get("_FillValue"),
                        shuffle = True,
                        compression = 'zlib',
                        complevel = 1,
                        chunksizes = chunking)

                # copy variable attributes all at once via dictionary
                dst_attrs = copy.copy(variable.__dict__)
                if attrs and dst_name in attrs:
                    dst_attrs.update(attrs[dst_name])
                if "_FillValue" in dst_attrs:
                    del dst_attrs["_FillValue"]

                x.setncatts(dst_attrs)

                # copy values
                x[:] = variable[:]


if __name__ == "__main__":
    main(sys.argv)
