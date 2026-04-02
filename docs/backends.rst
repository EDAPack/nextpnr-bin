Supported Backends
==================

Seven nextpnr backends are included, each as a separate binary.
All chipdb data is embedded in the binary at build time (no external data files
required at runtime), except where noted.

.. list-table::
   :header-rows: 1
   :widths: 30 20 50

   * - Binary
     - Target family
     - Source / chipdb dependency
   * - ``nextpnr-ice40``
     - Lattice iCE40
     - `Project IceStorm <https://clifford.at/icestorm>`_ — chipdb compiled in
   * - ``nextpnr-ecp5``
     - Lattice ECP5
     - `Project Trellis <https://github.com/YosysHQ/prjtrellis>`_ — chipdb compiled in
   * - ``nextpnr-machxo2``
     - Lattice MachXO2/3
     - Project Trellis — chipdb compiled in
   * - ``nextpnr-mistral``
     - Intel/Altera Cyclone V
     - `Mistral <https://github.com/Ravenslofty/mistral>`_ (libmistral linked in)
   * - ``nextpnr-himbaechel-gowin``
     - Gowin GW1N / GW2A
     - `Apicula <https://github.com/YosysHQ/apicula>`_ — ``share/nextpnr/himbaechel/gowin/`` ¹
   * - ``nextpnr-himbaechel-gatemate``
     - Cologne Chip GateMate
     - `Project Peppercorn <https://github.com/YosysHQ/prjpeppercorn>`_ — ``share/nextpnr/himbaechel/gatemate/`` ¹
   * - ``nextpnr-generic``
     - Generic / custom architectures
     - No chipdb

¹ **himbaechel** backends use external ``.bin`` chipdb files installed under
``share/nextpnr/`` next to the ``bin/`` directory.  The binary locates them
automatically via ``/proc/self/exe`` — the relative layout is preserved in the
tarball so this works from any extract path.

Build-time dependencies
-----------------------

The following libraries are built from source and either compiled into the
binaries or linked statically:

- **Boost** (all backends) — statically linked
- **libstdc++ / libgcc** — statically linked via ``-static-libstdc++ -static-libgcc``
- **IceStorm** (iCE40) — ``share/icebox/`` read at CMake configure time only
- **Trellis** (ECP5/MachXO2) — ``pytrellis.so`` imported at CMake configure time only
- **Mistral** (Cyclone V) — ``libmistral`` built and linked into the binary
- **Apicula** (Gowin) — Python generator invoked at CMake configure time only
- **Peppercorn** (GateMate) — device files read at CMake configure time only

Runtime shared-library dependencies are limited to universally available base
OS libraries: ``libc``, ``libm``, ``libz``, ``libbz2``, ``liblzma``,
``libzstd``, and ``ld-linux``.
