import os

from step import Step

def global_elevation(source_dir, filename, resolution):
    dirname = os.path.join(source_dir, 'GMTED2010')
    url = 'http://edcintl.cr.usgs.gov/downloads/sciweb1/shared/topo/downloads/GMTED/Grid_ZipFiles/mn30_grd.zip'
    zip_path = os.path.join(dirname, url.split('/')[-1])
    raw_file = os.path.join(dirname, 'mn30_grd')

    return [
        # Download elevation data
        Step(
            targets=zip_path,
            dependencies=[],
            commands=[
                [ 'wget', '--directory-prefix', dirname, url ]
            ]
        ),

        # Unzip elevation data
        Step(
            targets=raw_file,
            dependencies=zip_path,
            commands=[
                [ 'unzip', '-d', dirname, zip_path ],
                [ 'touch', raw_file ]
            ]
        ),

        # Aggregate elevation data
        Step(
            targets=filename,
            dependencies=raw_file,
            commands=[
                [
                    os.path.join('{BINDIR}', 'utils', 'isric_30sec_soils', 'aggregate_tawc.R'),
                    '--res', str(resolution),
                    '--input', raw_file,
                    '--output', filename
                ]
            ]
        )
    ]
