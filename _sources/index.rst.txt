nextpnr-bin
===========

**nextpnr-bin** provides pre-built, portable Linux x86_64 binaries of
`nextpnr <https://github.com/YosysHQ/nextpnr>`_, the open-source
place-and-route tool from the `YosysHQ <https://github.com/YosysHQ>`_ project.

Binaries are built inside a ``manylinux_2_34`` container so they run on any
Linux distribution with glibc ≥ 2.34 (Ubuntu 22.04+, RHEL 9+, Fedora 36+, …)
with no extra dependencies to install.

.. toctree::
   :maxdepth: 2
   :caption: Contents

   backends
   install
   build
