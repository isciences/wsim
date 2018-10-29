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
from typing import Union, Iterable, Optional, List

from .step import Step
from . import attributes as attrs


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


def exact_extract(*,
                  boundaries: str,
                  fid: str,
                  input: str,
                  output: str,
                  weights: Union[str, List[str], None]=None,
                  stats: Union[str, List[str]],
                  comment: Optional[str]=None):

    if isinstance(stats, str):
        stats = [stats]

    if isinstance(weights, str):
        weights = [weights]

    cmd = [
        'exactextract',
        '-p', boundaries,
        '-f', fid,
        '-r', input,
        '-o', output
    ]

    if weights:
        cmd += ['-w', weights]

    for stat in stats:
        cmd += ['-s', stat]

    import re

    # TODO tidy this up. We need to strip off GDAL stuff
    input=re.sub('^\w+:', '', input)
    input=re.sub(':\w+$', '', input)

    return Step(
        targets=output,
        dependencies=([input] + weights) if weights else input,
        commands=[cmd],
        comment=comment
    )


def wsim_extract(*, boundaries, fid, input, output, stats, keepvarnames=False, comment=None):
    if isinstance(stats, str):
        stats = [stats]

    cmd = [
        os.path.join('{BINDIR}', 'wsim_extract.R'),
        '--boundaries', q(boundaries),
        '--fid',        fid,
        '--input',      q(input),
        '--output',     q(output)
    ]

    for stat in stats:
        cmd += ['--stat', stat]

    if keepvarnames:
        cmd.append('--keepvarnames')

    return Step(
        targets=output,
        dependencies=[boundaries, input],
        commands=[cmd],
        comment=comment
    )


def wsim_fit(*,
             distribution: str,
             inputs: Union[str,Iterable[str]],
             output: str,
             window: int,
             comment: Union[str,None]=None):
    dependencies = []
    targets = []

    if type(inputs) is str:
        inputs = [inputs]

    cmd = [
        os.path.join('{BINDIR}', 'wsim_fit.R'),
        '--distribution', distribution,
    ]

    for i in inputs:
        cmd += ['--input', q(i)]
        dependencies.append(i)

    if window is not None:
        cmd += ['--attr', attrs.integration_window(var=None, months=window)]

    cmd += ['--output', output]
    targets.append(output)

    return Step(
        targets=targets,
        dependencies=dependencies,
        commands=[cmd],
        comment=comment
    )


def wsim_flow(*, input, flowdir, varname, output, comment=None):
    cmd = [
        os.path.join('{BINDIR}', 'wsim_flow.R'),
        '--input',   q(input),
        '--flowdir', q(flowdir),
        '--varname', varname,
        '--output',  output
    ]

    return Step(
        targets=output,
        dependencies=[input, flowdir],
        commands=[cmd],
        comment=comment
    )


def wsim_lsm(*,
             wc: str,
             flowdir: str,
             elevation: str,
             state: str,
             forcing: str,
             results: Union[str,None],
             next_state: Union[str, None],
             loop: Union[int, None]=None,
             comment: Union[str, None]=None):
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

    if results is not None:
        cmd += [ '--results',    q(results) ]

    if next_state is not None:
        cmd += [ '--next_state', q(next_state) ]

    if loop:
        cmd += ['--loop', str(loop)]

    return Step(
        targets=[results, next_state],
        dependencies=[wc, flowdir, elevation, state] + forcing,
        commands=[cmd],
        comment=comment
    )


def wsim_merge(*,
               inputs: Union[str,Iterable],
               output: str,
               attrs: Union[Iterable,None]=None,
               comment: Union[str,None]=None):
    cmd = [ os.path.join('{BINDIR}', 'wsim_merge.R') ]

    if type(inputs) is str:
        inputs = [inputs]

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

    if type(stats) is str:
        stats = [stats]

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


def table2nc(input: str, output: str, fid: str, column: str, comment: Union[str,None]=None):
    cmd = [
        os.path.join('{BINDIR}', 'utils', 'table2nc.R'),
        '--input',  input,
        '--output', output,
        '--fid',    fid,
        '--column', column
    ]

    return Step(
        targets=output,
        dependencies=input,
        commands=[cmd],
        comment=comment
    )


def create_tag(*, name, dependencies):
    return [Step(targets=dep, dependencies=name) for dep in dependencies]

