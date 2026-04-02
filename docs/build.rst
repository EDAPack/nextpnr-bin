Building from Source
====================

The build script produces identical output whether run locally or in CI —
both use the same ``manylinux_2_34_x86_64`` Docker image for reproducibility.

Prerequisites
-------------

- Docker
- ``bash`` / ``sh``
- Internet access (clones upstream repos and downloads dnf packages)

Local build
-----------

.. code-block:: sh

    # Clone this repo
    git clone https://github.com/EDAPack/nextpnr-bin.git
    cd nextpnr-bin

    # Run inside manylinux container (sets CI_BUILD=1 to install system packages)
    docker run --rm \
        --volume "$(pwd):/io" \
        --env CI_BUILD=1 \
        --workdir /io \
        quay.io/pypa/manylinux_2_34_x86_64 \
        /io/scripts/build.sh

The tarball is written to ``release/nextpnr-bin-manylinux-x64-<version>.tar.gz``.

Build phases
------------

``scripts/build.sh`` runs the following phases in order:

1. **System packages** (``CI_BUILD=1`` only) — ``dnf install`` of cmake, Boost,
   Eigen3, bzip2, zstd, gcc-c++, etc.
2. **Python packages** — ``pip install intervaltree apycula`` (needed by
   nextpnr CMake configure for Gowin chipdb generation)
3. **Clone nextpnr** — latest tag from ``YosysHQ/nextpnr``
4. **IceStorm** — clone & build ``YosysHQ/icestorm`` (``ICEPROG=0``)
5. **Trellis** — clone & build ``YosysHQ/prjtrellis`` (out-of-tree,
   ``INSTALL_LIBDIR=lib``)
6. **Mistral** — clone ``Ravenslofty/mistral`` branch ``nextpnr-latest``
   (source-only; built inline by nextpnr CMake)
7. **Peppercorn** — clone ``YosysHQ/prjpeppercorn`` (device files only)
8. **nextpnr CMake + build** — all backends enabled, ``STATIC_BUILD=OFF``,
   ``Boost_USE_STATIC_LIBS=ON``, ``-static-libstdc++ -static-libgcc``
9. **Strip** — ``strip --strip-unneeded`` on all binaries
10. **ldd check** — warns if any unexpected shared libraries are linked
11. **Package** — ``tar.gz`` created in ``release/``

Key CMake flags
---------------

.. list-table::
   :header-rows: 1
   :widths: 45 55

   * - Flag
     - Purpose
   * - ``-DSTATIC_BUILD=OFF``
     - Avoids global ``-static`` flag that breaks Mistral's CMake sub-project
   * - ``-DBoost_USE_STATIC_LIBS=ON``
     - Links Boost ``.a`` files instead of ``.so``
   * - ``-DBUILD_PYTHON=OFF``
     - No Python embedding → no libpython runtime dep
   * - ``-DBUILD_GUI=OFF``
     - No Qt dependency
   * - ``-DHIMBAECHEL_SPLIT=ON``
     - Builds separate ``nextpnr-himbaechel-<arch>`` binaries
   * - ``-DUSE_IPO=OFF``
     - Avoids link-time optimisation issues in the container

Cleaning build artifacts
------------------------

Build artifacts are created inside Docker as root.  To remove them::

    docker run --rm \
        --volume "$(pwd):/io" \
        quay.io/pypa/manylinux_2_34_x86_64 \
        sh -c "rm -rf /io/icestorm /io/prjtrellis /io/nextpnr /io/mistral \
               /io/prjpeppercorn /io/deps-install /io/nextpnr-build /io/release"
