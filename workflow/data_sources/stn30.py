import os

from step import Step

def global_flow_direction(source_dir, filename, resolution):
    if resolution != 0.5:
        raise ValueError('Only half-degree resolution is provided by STN-30')

    dirname = os.path.join(source_dir, 'STN_30')
    url = 'global_30_minute_potential_network_v601_asc.zip'
    zip_path = os.path.join(dirname, url.split('/')[-1])

    return [
        # Download flow grid
        Step(
            targets=zip_path,
            dependencies=[],
            commands=[
                [ 'wget', '--directory-prefix', dirname, url ]
            ]
        ),

        # Unzip flow grid
        Step(
            targets=filename,
            dependencies=zip_path,
            commands=[
                [ 'unzip', '-j', zip_path, 'global_potential_network_v601_asc/g_network.asc', '-d', dirname ],
                [ 'touch', filename ] # Make extracted date modified > archive date modified
            ]
        )
    ]
