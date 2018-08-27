# Copyright (c) 2018 ISciences, LLC.
# All rights reserved.
#
# WSIM is licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License. You may
# obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os

from .step import Step

def q(txt):
    return '"{}"'.format(txt)

def forecast_convert(infile, outfile, comment=None):
    return Step(
        targets=outfile,
        dependencies=infile,
        commands=[
            [os.path.join('{BINDIR}', 'utils', 'noaa_cfsv2_forecast', 'convert_cfsv2_forecast.sh'),
             infile,
             outfile]
        ],
        comment=comment
    )

def extract_from_tar(tarfile, to_extract, dest_dir, comment=None):
    """
    Returns a step to extract a single file from a tarfile and place it in a specified directory
    :param tarfile: path to tarfile
    :param to_extract: path of item within tarfile
    :param dest_dir: path to which item should be extracted (path within tarfile will be stripped)
    :return: command
    """
    trim_dirs = to_extract.count(os.sep)

    return Step(
        targets=os.path.join(dest_dir, os.path.basename(to_extract)),
        dependencies=tarfile,
        commands= [
            [
                'tar',
                'xzf',
                tarfile,
                '--no-same-owner', # prevent permission errors when extracting as root (such as within a Docker container)
                                   # to CIFS; explanation at the following URL:
                                   # https://www.krenger.ch/blog/linux-tar-cannot-change-ownership-to-permission-denied/
                '--strip-components', str(trim_dirs),
                '--directory', dest_dir,
                to_extract
            ]
        ],
        comment=comment
    )

def wsim_anom(*, fits, obs, rp=None, sa=None, comment=None):
    if type(fits) is str:
        fits = [fits]

    if type(obs) is str:
        obs = [obs]
    else:
        obs = [o for o in obs if o is not None]

    cmd = [
        os.path.join('{BINDIR}', 'wsim_anom.R')
    ]

    for f in fits:
        cmd += [ '--fits', q(f) ]

    for o in obs:
         cmd += [ '--obs',  q(o) ]

    if rp:
        cmd += ['--rp', q(rp)]
    if sa:
        cmd += ['--sa', q(sa)]

    return Step(
        targets=[rp, sa],
        dependencies=fits + obs,
        commands=[cmd],
        comment=comment
    )

def wsim_fit(*, distribution, inputs, output, comment=None):
    dependencies = []
    targets = []

    cmd = [
        os.path.join('{BINDIR}', 'wsim_fit.R'),
        '--distribution', distribution,
    ]

    for i in inputs:
        cmd += ['--input', q(i)]
        dependencies.append(i)

    cmd += ['--output', output]
    targets.append(output)

    return Step(
        targets=targets,
        dependencies=dependencies,
        commands=[cmd],
        comment=comment
    )

def wsim_lsm(*, wc, flowdir, elevation, state, forcing, results, next_state, loop=None, comment=None):
    cmd = [
        os.path.join('{BINDIR}', 'wsim_lsm.R'),
        '--wc',         q(wc),
        '--flowdir',    q(flowdir),
        '--elevation',  q(elevation),
        '--state',      q(state)]

    if isinstance(forcing, str):
        forcing = [forcing]

    for f in forcing:
        cmd += [ '--forcing', q(f) ]

    cmd += [
        '--results',    q(results),
        '--next_state', q(next_state)
    ]

    if loop:
        cmd += ['--loop', str(loop)]

    return Step(
        targets=[results, next_state],
        dependencies=[wc, flowdir, elevation, state] + forcing,
        commands=[cmd],
        comment=comment
    )

def wsim_merge(*, inputs, output, attrs=None, comment=None):
    cmd = [ os.path.join('{BINDIR}', 'wsim_merge.R') ]

    for arg in inputs:
        cmd += ['--input', q(arg)]

    cmd += ['--output', q(output)]

    if attrs:
        for attr in attrs:
            cmd += ['--attr', attr]

    return Step(
        targets=output,
        dependencies=inputs,
        commands=[cmd],
        comment=comment
    )


def wsim_correct(*, retro, obs, forecast, output, attrs=None, append=False, comment=None):
    if type(retro) is str:
        retro = [retro]

    if type(obs) is str:
        obs = [obs]

    cmd = [
        os.path.join('{BINDIR}', 'wsim_correct.R')
    ]

    for fit in retro:
        cmd += [ '--retro', q(fit) ]

    for fit in obs:
        cmd += [ '--obs', q(fit) ]

    cmd += [
        '--forecast', q(forecast),
        '--output',   q(output)
    ]

    if attrs:
        for attr in attrs:
            cmd += ['--attr', attr]

    if append:
        cmd.append('--append')

    return Step(
        targets=output,
        dependencies=retro + obs + [forecast],
        commands=[cmd],
        comment=comment
    )

def wsim_integrate(*, stats, inputs, output, window=None, keepvarnames=False, attrs=None, comment=None):
    cmd = [ os.path.join('{BINDIR}', 'wsim_integrate.R') ]

    for stat in stats:
        cmd += ['--stat', stat]

    if type(inputs) is str:
        inputs = [inputs]
    for i in inputs:
        cmd += '--input', q(i)

    if attrs:
        for attr in attrs:
            cmd += ['--attr', attr]

    if window:
        cmd += ['--window', str(window)]

    if keepvarnames:
        cmd.append('--keepvarnames')

    if type(output) is str:
        output = [output]

    for f in output:
        cmd += ['--output', q(f)]

    return Step(
        targets=output,
        dependencies=inputs,
        commands=[cmd],
        comment=comment
    )

def wsim_composite(*, surplus=None, deficit=None, both_threshold=None, mask=None, clamp=None, output, comment=None):
    cmd = [ os.path.join('{BINDIR}', 'wsim_composite.R') ]

    if surplus:
        for var in surplus:
            cmd += ['--surplus', q(var)]

    if deficit:
        for var in deficit:
            cmd += ['--deficit', q(var)]

    if both_threshold:
        cmd += ['--both_threshold', str(both_threshold)]

    if mask:
        cmd += ['--mask', q(mask)]

    if clamp:
        cmd += ['--clamp', str(clamp)]

    cmd += ['--output', q(output)]

    return Step(
        targets=output,
        dependencies=surplus + deficit + [mask],
        commands=[cmd],
        comment=comment
    )

def move(from_path, to_path):
    return Step(targets=to_path,
                consumes=from_path,
                dependencies=from_path,
                commands=[[ 'mv', q(from_path), q(to_path) ]])

def create_tag(*, name, dependencies):
    return [Step(targets=dep, dependencies=name) for dep in dependencies]

