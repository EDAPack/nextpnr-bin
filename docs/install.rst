Installation
============

Download
--------

Pre-built tarballs are published as `GitHub Releases
<https://github.com/EDAPack/nextpnr-bin/releases>`_.  Each release is named::

    nextpnr-bin-manylinux_2_34_x86_64-<version>.tar.gz

Extract to any directory.  The layout inside the tarball is::

    bin/
        nextpnr-ice40
        nextpnr-ecp5
        nextpnr-machxo2
        nextpnr-mistral
        nextpnr-himbaechel-gowin
        nextpnr-himbaechel-gatemate
        nextpnr-generic
    share/
        nextpnr/
            himbaechel/
                gowin/       ← Gowin chipdb (.bin files)
                gatemate/    ← GateMate chipdb (.bin files)

Add ``bin/`` to your ``PATH`` and all seven tools are ready to use.

Quick start::

    tar xf nextpnr-bin-manylinux_2_34_x86_64-<version>.tar.gz -C /opt/nextpnr
    export PATH=/opt/nextpnr/bin:$PATH
    nextpnr-ice40 --help

Via IVPM
--------

If your project uses `IVPM <https://github.com/fvutils/ivpm>`_, add
``nextpnr-bin`` as a package dependency.  IVPM will automatically prepend
``bin/`` to ``PATH`` so all ``nextpnr-*`` commands are available.

System requirements
-------------------

- Linux x86_64
- glibc ≥ 2.34 (Ubuntu 22.04+, RHEL/AlmaLinux/Rocky 9+, Fedora 36+, Debian 12+)
- No additional packages required
