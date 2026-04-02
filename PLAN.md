# nextpnr-bin Build Plan

## Overview

Create a multi-platform binary distribution of nextpnr (https://github.com/YosysHQ/nextpnr),
modelled on the yosys-bin project in `../yosys-bin`. The distribution should support as many
backends as practical, bundling all non-standard dependencies. Builds must work both locally
and via GitHub Actions CI.

---

## Modelling on yosys-bin

The yosys-bin project provides the template:

| Pattern | Details |
|---------|---------|
| Single `scripts/build.sh` | Detects CI vs local, installs packages, clones deps, builds, packages tarball |
| Docker for Linux CI | `quay.io/pypa/manylinux_2_34_x86_64` produces portable `manylinux` binaries |
| GitHub Actions CI | `.github/workflows/ci.yml` — runs build.sh in Docker, creates release, uploads artifact |
| Release tarball layout | `release/nextpnr-bin-<platform>-<version>.tar.gz` → unpacks to `nextpnr-<version>/` |
| ivpm.yaml | Declares package name and PATH prepend so downstream tools find `nextpnr-*` binaries |
| pyproject.toml | Optional Python packaging for pip-installable distribution |
| Version from upstream | CI queries the latest nextpnr git tag to set the release version |

---

## Backends to Include

| Backend | Architecture flag | Key Dependency | Status | Include? |
|---------|-------------------|----------------|--------|---------|
| ice40 (Lattice iCE40) | `ice40` | IceStorm | Stable | ✅ Yes |
| ecp5 (Lattice ECP5) | `ecp5` | Project Trellis | Stable | ✅ Yes |
| machxo2 (Lattice MachXO2) | `machxo2` | Project Trellis (shared) | Experimental | ✅ Yes (free, uses Trellis) |
| mistral (Intel Cyclone V) | `mistral` | Mistral C++ lib | Experimental | ✅ Yes |
| himbaechel-gowin | `himbaechel` + gowin uarch | Project Apicula | Experimental | ✅ Yes |
| himbaechel-gatemate | `himbaechel` + gatemate uarch | Project Peppercorn | Experimental | ✅ Yes |
| generic | `generic` | None | Stable | ✅ Yes |
| nexus (Lattice Nexus) | `nexus` | Project Oxide (Rust) | Experimental | ❌ Skip (requires Rust toolchain) |
| ng-ultra (NanoXplore) | `himbaechel` + ng-ultra | prjbeyond-db + proprietary tools | Experimental | ❌ Skip (requires NanoXplore Impulse tool) |
| Xilinx 7-series | `all+alpha` | Project X-Ray (incomplete) | Alpha | ❌ Skip (minimal/incomplete support) |

**Build flag:** `-DARCH="ice40;ecp5;machxo2;mistral;himbaechel;generic"`  
**Himbaechel uarchs:** `-DHIMBAECHEL_UARCH="gowin;gatemate"`

---

## Non-Standard Dependencies (Must Be Built from Source)

These are NOT available as standard distro packages and must be cloned + built before nextpnr.

### How nextpnr Locates Each Dependency

| Dependency | CMake variable | Also reads env var? | What it points to |
|------------|---------------|---------------------|-------------------|
| IceStorm | `ICESTORM_INSTALL_PREFIX` | ✅ `$ICESTORM_INSTALL_PREFIX` | Install prefix; looks for `share/icebox/` underneath |
| Trellis | `TRELLIS_INSTALL_PREFIX` | ✅ `$TRELLIS_INSTALL_PREFIX` | Install prefix; looks for `lib/trellis/pytrellis.so` and `share/trellis/` |
| Mistral | `MISTRAL_ROOT` | ❌ no env var | Path to a Mistral **source checkout** — nextpnr adds it as `add_subdirectory()` |
| Apicula | `APYCULA_INSTALL_PREFIX` | ✅ `$APYCULA_INSTALL_PREFIX` | Optional venv path; if unset uses system Python. Package must be pip-importable |
| Peppercorn | `HIMBAECHEL_PEPPERCORN_PATH` | ❌ no env var | Path to prjpeppercorn source checkout; looks for `gatemate/` subdir with device files |

IceStorm and Trellis use custom `cmake/FindIceStorm.cmake` / `cmake/FindTrellis.cmake` modules.  
Mistral and Peppercorn require a raw source checkout (not an installed prefix).  
Apicula is purely a Python package invoked at CMake configure time for code generation.

---

### 1. Project IceStorm
- **URL:** https://github.com/YosysHQ/icestorm
- **Language:** Python + C++
- **Purpose:** iCE40 chipdb (timing data) for ice40 backend
- **Build:** Build all tools except `iceprog` (which needs libftdi for USB), then copy chipdb data files directly: `cp -r icebox/* $DEPS_PREFIX/share/icebox/`
- **System deps needed:** none beyond base build tools (`libftdi` only needed for the programmer tool, not for chipdb)
- **nextpnr CMake:** `-DICESTORM_INSTALL_PREFIX=$DEPS_PREFIX`
  - Looks for `$DEPS_PREFIX/share/icebox/chipdb-*.txt`
- **Runtime note:** chipdb is compiled into nextpnr-ice40 at build time — `share/icebox/` is NOT needed at runtime

### 2. Project Trellis
- **URL:** https://github.com/YosysHQ/prjtrellis
- **Language:** Python + C++
- **Purpose:** ECP5 + MachXO2 chipdb + pytrellis library (used at nextpnr build time)
- **Build:**
  ```
  git submodule update --init --recursive
  cd libtrellis
  cmake -DCMAKE_INSTALL_PREFIX=$DEPS_PREFIX .
  make -j$(nproc) && make install
  ```
- **System deps needed:** `libffi-dev`; Python package `intervaltree` (`pip install intervaltree`)
- **nextpnr CMake:** `-DTRELLIS_INSTALL_PREFIX=$DEPS_PREFIX`
  - Looks for `$DEPS_PREFIX/lib/trellis/pytrellis.so` and `$DEPS_PREFIX/share/trellis/`

### 3. Mistral (Intel Cyclone V)
- **URL:** https://github.com/Ravenslofty/mistral
- **Branch:** `nextpnr-latest` (not master — API differs)
- **Language:** C++
- **Purpose:** Cyclone V chipdb, embedded directly into the nextpnr-mistral binary at build time
- **Build:** nextpnr builds it as a subdirectory — no separate install step needed
- **System deps needed:** `liblzma-dev` (XZ utils dev headers)
- **nextpnr CMake:** `-DMISTRAL_ROOT=$MISTRAL_CHECKOUT_DIR`
  - Must point to the cloned source tree (not an install prefix)
  - nextpnr calls `add_subdirectory($MISTRAL_ROOT/libmistral)` etc.

### 4. Project Apicula (Gowin)
- **URL:** https://github.com/YosysHQ/apicula  (pip package: `apycula`)
- **Language:** Python
- **Purpose:** Gowin chipdb generator — `gowin_arch_gen.py` is invoked by CMake at configure time
- **Build:** `pip install apycula`  (no separate source checkout needed)
- **nextpnr CMake:** `-DAPYCULA_INSTALL_PREFIX=` (leave unset to use system Python, or point to a venv)
  - CMake will call the `gowin_arch_gen.py` script via whatever Python has `apycula` installed

### 5. Project Peppercorn (GateMate)
- **URL:** https://github.com/YosysHQ/prjpeppercorn
- **Language:** Python
- **Purpose:** GateMate device database files used during chipdb generation
- **Build:** Clone the repo; no install step — CMake reads files directly from the source tree
- **System deps needed:** `liblzma-dev`
- **nextpnr CMake:** `-DHIMBAECHEL_PEPPERCORN_PATH=$PEPPERCORN_CHECKOUT_DIR`
  - Must point to the cloned source tree; nextpnr looks for `$PEPPERCORN_CHECKOUT_DIR/gatemate/`

---

## Standard System Dependencies (Linux / manylinux dnf)

```
cmake python3-devel boost-devel boost-static eigen3-devel
libffi-devel zlib-devel xz-devel gcc-c++ git make pkg-config
```

---

## Portability Strategy

**Goal:** produce binaries that run on any Linux x86_64 with glibc ≥ 2.34 (manylinux_2_34 baseline) with no extra packages beyond common system libs.

| Concern | Solution |
|---------|---------|
| Boost dynamic libs | `Boost_USE_STATIC_LIBS=ON` → Boost `.a` files linked in |
| libstdc++ version skew | `-static-libstdc++ -static-libgcc` in `CMAKE_EXE_LINKER_FLAGS` |
| libpython runtime dep | `-DBUILD_PYTHON=OFF` — no Python in the binary |
| Qt runtime deps | `-DBUILD_GUI=OFF` — no GUI |
| NOT using STATIC_BUILD=ON | Full `-static` breaks Mistral's `add_subdirectory()` C compiler test (requires glibc-static). Not needed — manylinux uses glibc backward compat instead. |
| libbz2/libz/liblzma/libzstd | Boost iostreams transitive deps; linked dynamically. All four are universal base-OS libraries on every modern Linux distro. |
| IceStorm/Trellis chipdb at runtime | None — chipdb compiled into binary (BBA). `share/icebox/` and `share/trellis/` are build-time only |
| himbaechel chipdb at runtime | **External** `.bin` files installed to `share/nextpnr/himbaechel/{gowin,gatemate}/`. Binary locates them via `/proc/self/exe` — looks for `../share/nextpnr/` relative to binary. Fully portable from any extract location. |
| pytrellis.so at runtime | Not needed — only imported by CMake configure-time scripts |
| Apicula at runtime | Not needed — Python generator runs at CMake configure time only |
| Peppercorn at runtime | Not needed — device files read at CMake configure time only |

**Binary sizes (stripped):** generic/himbaechel 3–4 MB; ecp5 105 MB; machxo2 138 MB; ice40 223 MB; mistral 279 MB  
**Tarball:** ~438 MB compressed

**Verification:** `build.sh` runs an `ldd` check post-build and warns on any unexpected `.so` beyond the known-acceptable baseline.

---


## Repository Layout

```
nextpnr-bin/
├── .github/
│   └── workflows/
│       └── ci.yml            # GitHub Actions: build + release
├── scripts/
│   └── build.sh              # Main build script (local + CI)
├── ivpm.yaml                 # IVPM package descriptor
├── pyproject.toml            # Python packaging (optional)
├── LICENSE
└── PLAN.md                   # This file
```

---

## Build Script Design (`scripts/build.sh`)

```
Phase 0: Detect CI vs local, set platform, install system packages
Phase 1: Clone / update nextpnr source (git submodule update --init)
Phase 2: Build IceStorm → make install PREFIX=$DEPS_PREFIX
Phase 3: Build Project Trellis → cmake install to $DEPS_PREFIX
Phase 4: Clone Mistral (branch nextpnr-latest) → source checkout only (built by nextpnr)
Phase 5: pip install apycula (Apicula/Gowin generator)
Phase 6: Clone Project Peppercorn → source checkout only (nextpnr reads files directly)
Phase 7: Configure nextpnr with CMake (all backends, static build, no GUI, no Python)
Phase 8: Build nextpnr
Phase 9: Install binaries to $release_dir/bin/
Phase 10: Package tarball: nextpnr-bin-<platform>-<version>.tar.gz
```

Key CMake flags:
```cmake
-DARCH="ice40;ecp5;machxo2;mistral;himbaechel;generic"
-DHIMBAECHEL_UARCH="gowin;gatemate"
-DBUILD_GUI=OFF
-DBUILD_PYTHON=OFF
-DSTATIC_BUILD=ON
-DCMAKE_BUILD_TYPE=Release
-DUSE_IPO=ON
-DICESTORM_INSTALL_PREFIX=$DEPS_PREFIX
-DTRELLIS_INSTALL_PREFIX=$DEPS_PREFIX
-DMISTRAL_ROOT=$MISTRAL_CHECKOUT_DIR
-DHIMBAECHEL_PEPPERCORN_PATH=$PEPPERCORN_CHECKOUT_DIR
# APYCULA_INSTALL_PREFIX not set → uses system Python (apycula installed via pip)
```

---

## GitHub Actions CI (`.github/workflows/ci.yml`)

- **Trigger:** push, workflow_dispatch, weekly schedule (Sunday)
- **Linux job:** Run `scripts/build.sh` inside `quay.io/pypa/manylinux_2_34_x86_64` Docker container (same as yosys-bin)
  - Produces: `nextpnr-bin-manylinux-x64-<version>.tar.gz`
- **Version:** Query latest nextpnr git tag; append `$BUILD_NUM` (run ID) as patch version
- **Release:** Create GitHub Release with tag `v<version>`; upload tarball as asset
- **macOS job (future):** Run natively on `macos-latest` runner, package as `nextpnr-bin-macos-x64-<version>.tar.gz`

---

## Release Tarball Layout

```
nextpnr-<version>/
├── bin/
│   ├── nextpnr-ice40
│   ├── nextpnr-ecp5
│   ├── nextpnr-machxo2
│   ├── nextpnr-nexus
│   ├── nextpnr-mistral
│   ├── nextpnr-himbaechel   (covers gowin + gatemate)
│   └── nextpnr-generic
├── share/
│   └── nextpnr/             (chipdb data files, if any are installed externally)
├── ivpm.yaml
├── pyproject.toml
└── LICENSE
```

---

## Local Build

```bash
# Clone this repo
git clone https://github.com/<org>/nextpnr-bin
cd nextpnr-bin

# Run build locally (installs system deps if run as root / sudo)
./scripts/build.sh

# Output: release/nextpnr-bin-linux-x64-<version>.tar.gz
```

The script should detect non-CI environment and:
- Skip `dnf update` / Docker-specific setup
- Allow overriding `DEPS_PREFIX`, `CARGO_HOME`, `release_dir` via env vars
- Build to `./build/` and package to `./release/`

---

## Open Questions / Risks

1. **Static linking with Boost on manylinux** – Boost static libs are available in the manylinux image; verify `-DSTATIC_BUILD=ON` links correctly without missing symbols.
2. **Mistral chipdb size** – Mistral embeds Cyclone V chipdb; binary may be large.
3. **Apicula/Peppercorn at CMake time** – These Python generators are invoked during CMake configure (`cmake ..`), so `apycula` must be pip-installed and `HIMBAECHEL_PEPPERCORN_PATH` must be set before running CMake.
4. **machxo2 stability** – Listed as experimental and shares Trellis; should work with same install prefix.
5. **IPO/LTO link time** – With all backends, full LTO may significantly increase link time (10-30 min). Consider `-DUSE_IPO=OFF` if CI timeouts occur.
6. **himbaechel split** – With `-DHIMBAECHEL_SPLIT=ON`, gowin and gatemate get separate binaries. Easier for users; slightly larger release. Worth considering.
