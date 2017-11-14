Development
***********

The WSIM source code and issue tracker are hosted at `GitLab <https://gitlab.com/isciences/wsim/wsim2>`_. All project code and documentation is stored in a single repository.

Structure
=========

The core functionality of WSIM is provided through R packages.
These packages are generally independent, but some functionality of ``wsim.io`` is accessed from other packages.
Where performance is critical, code is written in C++ and exposed to R using the Rcpp package.
Some use is made of C++11, which is not compliant with CRAN.

Functionality provided by the R packages is exposed to users through a series of command-line tools.

The package build process, including compilation of C++ sources, is done using the ``devtools`` package.
Each package contains a ``Makefile``, and package testing and installation can be performed using the ``check`` and ``install`` targets, respectively.

Testing
=======

Each R package contains an independent test suite, managed using the ``testthat`` package.
Currently, a small number of tests depend on resources stored on the ISciences internal network.
These tests are automatically skipped when these resources are inaccessible.

Tests are run on commit using GitLab `CI <https://gitlab.com/isciences/wsim/wsim2/pipelines>`_.
The build environment used by the GitLab CI runner is managed using Docker.
A Dockerfile for this image is stored within the ``ci`` subdirectory of the repository.
The image itself is published to Docker Hub as ``isciences/wsim-gitlabci``.
This image does not contain WSIM code or binaries, but includes all dependencies needed to build the code and run the test suite.

Documentation
=============

General WSIM documentation, such as this page is generated using Sphinx from manually-authored reST files stored in the git repository.

R package documentation is automatically generated from source comments, using the ``Roxygen2`` package.
The HTML versions of this documentation are generated using ``pkgdown``.

Documentation can be built using the ``html`` target for ``make``.
