Obtaining WSIM
**************

WSIM can be obtained from Docker Hub or from GitLab.

From Docker Hub
===============

WSIM is most easily obtained from `Docker Hub <https://hub.docker.com>`_.
The WSIM image is currently stored in a private repository, with access granted by request.
To pull the image from the repository, run the following commands on a system with Docker installed:

.. code-block:: console

   docker login
   docker pull isciences/wsim:2_latest

You can run the WSIM container in interactive mode using:

.. code-block:: console

   docker run -it isciences/wsim:2_latest

Refer to Docker documentation for more details, such as accessing the local filesystem from within the running container.

From GitLab
===========

A copy of the WSIM source code can be downloaded from GitLab at `this url <https://gitlab.com/isciences/wsim/wsim2/repository/master/archive.zip>`_.
Access to the ``wsim2`` project is required.
Some WSIM functionality has external dependencies on tools such as ``wgrib2`` and ``nco`` that are not included in the repository.
These tools are found in the WSIM Docker image, or can be installed manually.