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

from step import Step

def q(txt):
    return '"{}"'.format(txt)

def forecast_convert(infile, outfile):
    return Step(
        targets=outfile,
        dependencies=infile,
        commands=[
            [os.path.join('{BINDIR}', 'utils', 'noaa_cfsv2_forecast', 'convert_cfsv2_forecast.sh'),
             infile,
             outfile]
        ]
    )

def extract_from_tar(tarfile, to_extract, dest_dir):
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
                '--strip-components', str(trim_dirs),
                '--directory', dest_dir,
                to_extract
            ]
        ]
    )

def wsim_anom(*, fits, obs, rp=None, sa=None):
    cmd = [
        os.path.join('{BINDIR}', 'wsim_anom.R'),
        '--fits', q(fits),
        '--obs',  q(obs)
    ]

    if rp:
        cmd += ['--rp', q(rp)]
    if sa:
        cmd += ['--sa', q(sa)]

    return Step(
        targets=[rp, sa],
        dependencies=[fits, obs],
        commands=[cmd]
    )

def wsim_fit(*, distribution, inputs, output):
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
        commands=[cmd]
    )

def wsim_lsm(*, wc, flowdir, elevation, state, forcing, results, next_state, loop=None):
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
        commands=[cmd]
    )

def wsim_merge(*, inputs, output, attrs=None):
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
        commands=[cmd]
    )

def wsim_correct(*, retro, obs, forecast, output, append=False):
    cmd = [
        os.path.join('{BINDIR}', 'wsim_correct.R'),
        '--retro',    q(retro),
        '--obs',      q(obs),
        '--forecast', q(forecast),
        '--output',   q(output)
    ]

    if append:
        cmd.append('--append')

    return Step(
        targets=output,
        dependencies=[retro, obs, forecast],
        commands=[cmd]
    )

def wsim_integrate(*, stats, inputs, output, window=None, keepvarnames=False, attrs=None):
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
        commands=[cmd]
    )

def wsim_composite(*, surplus=None, deficit=None, both_threshold=None, mask=None, clamp=None, output):
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
        commands=[cmd]
    )

