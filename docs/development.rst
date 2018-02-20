Development
***********

The WSIM source code and issue tracker are hosted at `GitLab <https://gitlab.com/isciences/wsim/wsim2>`_. All project code and documentation is stored in a single repository.

Structure
=========

The core functionality of WSIM is provided through R packages.
These packages are generally independent, but some functionality of ``wsim.io`` is accessed from other packages.
Where performance is critical, code is written in C++ and exposed to R using the ``Rcpp`` package.
Some use is made of C++11, which is not compliant with CRAN.

Functionality provided by the R packages is exposed to users through a series of command-line tools.

The package build process, including compilation of C++ sources, is done using the ``devtools`` package.
Each package contains a ``Makefile``, and package testing and installation can be performed using the ``check`` and ``install`` targets, respectively.

Testing
=======

Each R package contains an independent test suite, managed using the ``testthat`` package.
Currently, a small number of regression tests depend on resources that are not included in the git repository.
If these resources are available, their location must be specified with the ``WSIM_TEST_DATA`` environment variable.
These tests are automatically skipped when these resources are inaccessible.

.. note::
   The ``isciences/wsim-gitlabci`` Docker image contains all files necessary to run regression tests.

Tests are run on commit using GitLab `CI <https://gitlab.com/isciences/wsim/wsim2/pipelines>`_.
The GitLab CI test runner pulls the latest published image of the ``isciences/wsim-gitlabci`` build environment.
It builds the ``isciences/wsim`` image on top of this environment, and then runs the test suite within the built container.
If the tests pass (and the commit is to the `master` branch), GitLab CI tags the image as ``isciences/wsim:2_latest`` and pushes it to Docker Hub.

.. note::
   The ``isciences/wsim-gitlabci`` image is manually built and pushed when needed.
   This is done to reduce the execution time of the GitLab CI build and test pipeline.

Documentation
=============

General WSIM documentation (such as this page) is generated using Sphinx from manually-authored reST files stored in the git repository.

R package documentation is automatically generated from source comments, using the ``Roxygen2`` package.
The HTML versions of this documentation are generated using ``pkgdown``.

Documentation can be built using the ``html`` target for ``make``.
