#!/usr/bin/env python3

# Import setuptools if we have it (so we can use ./setup.py develop)
# but stick with distutils if we don't (so we can install it without
# needing tools outside of the standard library)
try:
    from setuptools import setup
except ImportError:
    from distutils.core import setup


setup(
    name='wsim_workflow',
    version='0.1',
    url='https://wsim.isciences.com',
    author='ISciences, LLC',
    author_email='dbaston@isciences.com',
    packages=[
        'wsim_workflow',
        'wsim_workflow.output',
        'wsim_workflow.data_sources'
    ]
)
