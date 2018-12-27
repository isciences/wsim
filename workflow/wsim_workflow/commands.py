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

from .paths import Vardef, gdaldataset2filename
from .step import Step
from . import attributes


def q(txt: str) -> str:
    return '"{}"'.format(txt)


def forecast_convert(infile: str, outfile: str, comment: Optional[str]=None) -> Step:
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


def extract_from_tar(tarfile: str, to_extract: str, dest_dir: str, comment: Optional[str]=None) -> Step:
    """
    Returns a step to extract a single file from a tarfile and place it in a specified directory
    :param tarfile: path to tarfile
    :param to_extract: path of item within tarfile
    :param dest_dir: path to which item should be extracted (path within tarfile will be stripped)
    :param comment: optional comment to include in Makefile
    :return: command
    """
    trim_dirs = to_extract.count(os.sep)

    return Step(
        targets=os.path.join(dest_dir, os.path.basename(to_extract)),
        dependencies=tarfile,
        commands=[
            [
                'tar',
                'xzf',
                tarfile,
                '--no-same-owner',  # prevent permission errors when extracting as root (such as within a
                                    # Docker container) to CIFS; explanation at the following URL:
                                    # https://www.krenger.ch/blog/linux-tar-cannot-change-ownership-to-permission-denied/
                '--strip-components', str(trim_dirs),
                '--directory', dest_dir,
                to_extract
            ]
        ],
        comment=comment
    )


def wsim_anom(*,
              fits: Union[str, List[str]],
              obs: Union[str, List[str]],
              rp: Optional[str]=None,
              sa: Optional[str]=None,
              comment: Optional[str]=None) -> Step:
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
        cmd += ['--fits', q(f)]

    for o in obs:
        cmd += ['--obs',  q(o)]

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


# noinspection PyShadowingBuiltins
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
    elif weights is None:
        weights = []

    cmd = [
        'exactextract',
        '-p', q(boundaries),
        '-f', q(fid),
        '-r', q(input),
        '-o', q(output)
    ]

    if weights:
        for w in weights:
            cmd += ['-w', q(w)]

    for stat in stats:
        cmd += ['-s', q(stat)]

    return Step(
        targets=output,
        dependencies=[gdaldataset2filename(ds) for ds in weights + [input] + [boundaries]],
        commands=[cmd],
        comment=comment
    )


# noinspection PyShadowingBuiltins
def wsim_extract(*,
                 boundaries: str,
                 fid: str,
                 input: str,
                 output: str,
                 stats: Union[str, List[str]],
                 keepvarnames: bool=False,
                 comment: Optional[str]=None) -> Step:
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
             inputs: Union[str, Iterable[str]],
             output: str,
             window: int,
             comment: Union[str, None]=None):
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
        cmd += ['--attr', attributes.integration_window(var=None, months=window)]

    cmd += ['--output', output]
    targets.append(output)

    return Step(
        targets=targets,
        dependencies=dependencies,
        commands=[cmd],
        comment=comment
    )


# noinspection PyShadowingBuiltins
def wsim_flow(*,
              input: Union[str, Vardef],
              flowdir: Union[str, Vardef],
              varname: str,
              output: str,
              comment: Optional[str]=None) -> Step:
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
             wc: Union[str, Vardef],
             flowdir: Union[str, Vardef],
             elevation: Union[str, Vardef],
             state: str,
             forcing: Union[str, List[str]],
             results: Optional[str],
             next_state: Optional[str],
             loop: Optional[int]=None,
             comment: Optional[str]=None) -> Step:
    cmd = [
        os.path.join('{BINDIR}', 'wsim_lsm.R'),
        '--wc',         q(wc),
        '--flowdir',    q(flowdir),
        '--elevation',  q(elevation),
        '--state',      q(state)]

    if isinstance(forcing, str):
        forcing = [forcing]

    for f in forcing:
        cmd += ['--forcing', q(f)]

    if results is not None:
        cmd += ['--results',    q(results)]

    if next_state is not None:
        cmd += ['--next_state', q(next_state)]

    if loop:
        cmd += ['--loop', str(loop)]

    return Step(
        targets=[results, next_state],
        dependencies=[wc, flowdir, elevation, state] + forcing,
        commands=[cmd],
        comment=comment
    )


def wsim_merge(*,
               inputs: Union[str, List[str]],
               output: str,
               attrs: Optional[List[str]]=None,
               comment: Optional[str]=None) -> Step:
    cmd = [os.path.join('{BINDIR}', 'wsim_merge.R')]

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


def wsim_correct(*,
                 retro: Union[str, List[str]],
                 obs: Union[str, List[str]],
                 forecast: str,
                 output: str,
                 attrs: Optional[List[str]]=None,
                 append: bool=False,
                 comment: Optional[str]=None) -> Step:
    if type(retro) is str:
        retro = [retro]

    if type(obs) is str:
        obs = [obs]

    cmd = [
        os.path.join('{BINDIR}', 'wsim_correct.R')
    ]

    for fit in retro:
        cmd += ['--retro', q(fit)]

    for fit in obs:
        cmd += ['--obs', q(fit)]

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


def wsim_integrate(*,
                   stats: Union[str, List[str]],
                   inputs: Union[str, List[str]],
                   output: str,
                   window: Optional[int]=None,
                   keepvarnames: bool=False,
                   attrs: Optional[List[str]]=None,
                   comment: Optional[str]=None) -> Step:
    cmd = [os.path.join('{BINDIR}', 'wsim_integrate.R')]

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


def wsim_composite(*,
                   surplus: Optional[List[str]]=None,
                   deficit: Optional[List[str]]=None,
                   both_threshold: Optional[Union[int, float]]=None,
                   mask: Optional[str]=None,
                   clamp: Optional[int]=None,
                   output: str,
                   comment: Optional[str]=None) -> Step:
    cmd = [os.path.join('{BINDIR}', 'wsim_composite.R')]

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


def move(from_path: str, to_path: str) -> Step:
    return Step(targets=to_path,
                consumes=from_path,
                dependencies=from_path,
                commands=[['mv', q(from_path), q(to_path)]])


# noinspection PyShadowingBuiltins
def table2nc(input: str, output: str, fid: str, column: str, comment: Optional[str]=None) -> Step:
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
