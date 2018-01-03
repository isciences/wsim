import os

def q(txt):
    return '"{}"'.format(txt)

def forecast_convert(infile, outfile):
    return [
        os.path.join('{BINDIR}', 'utils', 'noaa_cfsv2_forecast', 'convert_cfsv2_forecast.sh'),
        q(infile),
        q(outfile)
    ]

def wsim_anom(**kwargs):
    cmd = [
        os.path.join('{BINDIR}', 'wsim_anom.R'),
        '--fits', q(kwargs['fits']),
        '--obs',  q(kwargs['obs'])
    ]

    if 'rp' in kwargs:
        cmd += '--rp', q(kwargs['rp'])
    if 'sa' in kwargs:
        cmd += '--sa', q(kwargs['sa'])

    return cmd

def wsim_fit(**kwargs):
    cmd = [
        os.path.join('{BINDIR}', 'wsim_fit.R'),
        '--distribution', kwargs['distribution'],
    ]

    for input in kwargs['inputs']:
        cmd += ['--input', q(input)]

    cmd += ['--output', q(kwargs['output'])]

    return cmd

def wsim_lsm(**kwargs):
    cmd = [
        os.path.join('{BINDIR}', 'wsim_lsm.R'),
        '--wc',         q(kwargs['wc']),
        '--flowdir',    q(kwargs['flowdir']),
        '--elevation',  q(kwargs['elevation']),
        '--state',      q(kwargs['state'])]

    if type(kwargs['forcing']) is str:
        cmd += [ '--forcing',    q(kwargs['forcing']) ]
    else:
        for forcing in kwargs['forcing']:
            cmd += [ '--forcing', q(forcing) ]

    cmd += [
        '--results',    q(kwargs['results']),
        '--next_state', q(kwargs['next_state'])
    ]

    if 'loop' in kwargs:
        cmd += ['--loop', str(kwargs['loop'])]

    return cmd

def wsim_merge(**kwargs):
    cmd = [ os.path.join('{BINDIR}', 'wsim_merge.R') ]

    for arg in kwargs['inputs']:
        cmd += ['--input', q(arg)]

    cmd += ['--output', q(kwargs['output'])]

    attrs = kwargs.get('attrs', [])
    for attr in attrs:
        cmd += ['--attr', attr]

    return cmd

def wsim_correct(**kwargs):
    cmd = [
        os.path.join('{BINDIR}', 'wsim_correct.R'),
        '--retro',    q(kwargs['retro']),
        '--obs',      q(kwargs['obs']),
        '--forecast', q(kwargs['forecast']),
        '--output',   q(kwargs['output'])
    ]

    if kwargs.get('append'):
        cmd.append('--append')

    return cmd

def wsim_integrate(**kwargs):
    cmd = [ os.path.join('{BINDIR}', 'wsim_integrate.R') ]

    for stat in kwargs['stats']:
        cmd += ['--stat', stat]

    inputs = kwargs['inputs']
    if type(inputs) is str:
        inputs = [inputs]
    for input in inputs:
        cmd += '--input', q(input)

    for attr in kwargs.get('attrs', []):
        cmd += ['--attr', attr]

    if 'window' in kwargs:
        cmd += ['--window', str(kwargs['window'])]

    output = kwargs['output']
    if type(output) is str:
        output = [output]

    for f in output:
        cmd += ['--output', q(f)]

    return cmd

def wsim_composite(**kwargs):
    cmd = [ os.path.join('{BINDIR}', 'wsim_composite.R') ]

    for var in kwargs.get('surplus', []):
        cmd += ['--surplus', q(var)]

    for var in kwargs.get('deficit', []):
        cmd += ['--deficit', q(var)]

    if 'both_threshold' in kwargs:
        cmd += ['--both_threshold', str(kwargs['both_threshold'])]

    if 'mask' in kwargs:
        cmd += ['--mask', q(kwargs['mask'])]

    cmd += ['--output', q(kwargs['output'])]

    return cmd

