#!/bin/sh -x
#
# Build script for nextpnr-bin.
#
# Builds nextpnr with the following backends:
#   ice40, ecp5, machxo2, mistral, himbaechel (gowin + gatemate), generic
#
# All non-standard dependencies are built from source and embedded or linked
# statically so that the resulting nextpnr-* binaries are portable.
#
# Usage:
#   ./scripts/build.sh                   # local build
#   CI_BUILD=1 ./scripts/build.sh        # CI build (installs system packages)
#
# Override variables:
#   nextpnr_version  - version string for the release (default: 0.0.1)
#   rls_plat         - platform tag for tarball name (default: linux-x64)

set -e

root=$(pwd)
proj=$(pwd)

# ── CI environment setup ──────────────────────────────────────────────────────
if test "x${CI_BUILD}" != "x"; then
    if test "$(uname -s)" = "Linux"; then
        dnf update -y
        # Core build tools
        dnf install -y \
            cmake \
            python3-devel \
            boost-devel \
            boost-static \
            eigen3-devel \
            libffi-devel \
            zlib-devel \
            xz-devel \
            bzip2-devel \
            libzstd-devel \
            gcc-c++ \
            git \
            make \
            pkg-config

        # Use Python 3.10 from the manylinux image as the build interpreter
        export PATH=/opt/python/cp310-cp310/bin:$PATH

        rls_plat="manylinux-x64"
    fi
fi

# Default platform tag for local builds
if test "x${rls_plat}" = "x"; then
    rls_plat="linux-x64"
fi

# ── Version ───────────────────────────────────────────────────────────────────
if test "x${nextpnr_version}" != "x"; then
    rls_version=${nextpnr_version}
else
    rls_version=0.0.1
fi

deps_prefix="${proj}/deps-install"
mkdir -p "${deps_prefix}"

release_dir="${root}/release/nextpnr-${rls_version}"
rm -rf "${release_dir}"
mkdir -p "${release_dir}/bin"

# Allow git to operate on directories that may be owned by the host user
# (relevant when running as root inside a container with a bind-mounted repo).
git config --global --add safe.directory "${proj}" 2>/dev/null || true

# ── Python build-time dependencies ───────────────────────────────────────────
# intervaltree: required by prjtrellis Python scripts at CMake configure time
# apycula:      gowin chipdb generator invoked by nextpnr CMake for himbaechel-gowin
pip install intervaltree apycula --quiet
if test $? -ne 0; then exit 1; fi

# ── Clone nextpnr ─────────────────────────────────────────────────────────────
if test ! -d nextpnr; then
    git clone https://github.com/YosysHQ/nextpnr
    if test $? -ne 0; then exit 1; fi
fi
git config --global --add safe.directory "${proj}/nextpnr" 2>/dev/null || true
cd "${proj}/nextpnr"
git submodule update --init
if test $? -ne 0; then exit 1; fi
cd "${proj}"

# ── Build IceStorm ────────────────────────────────────────────────────────────
# We only need the chipdb data files (share/icebox/) for nextpnr's build-time
# chipdb generation.  The hardware programmer (iceprog) requires libftdi and
# is not needed here; we skip it by building selected subdirs only, then copy
# the data files directly.
if test ! -d icestorm; then
    git clone https://github.com/YosysHQ/icestorm
    if test $? -ne 0; then exit 1; fi
fi
git config --global --add safe.directory "${proj}/icestorm" 2>/dev/null || true
cd "${proj}/icestorm"
# Build without iceprog (ICEPROG defaults to 1 in config.mk but needs libftdi).
# The icebox subdir generates chipdb-*.txt from Python scripts; this is what
# nextpnr's FindIceStorm.cmake looks for under $ICESTORM_INSTALL_PREFIX/share/icebox/.
make -j$(nproc) ICEPROG=0 PREFIX="${deps_prefix}"
if test $? -ne 0; then exit 1; fi
make install ICEPROG=0 PREFIX="${deps_prefix}"
if test $? -ne 0; then exit 1; fi
cd "${proj}"

# ── Build Project Trellis ─────────────────────────────────────────────────────
# Provides pytrellis (a Python extension) used by nextpnr CMake to generate
# the ECP5/MachXO2 chipdb.  pytrellis.so is a build-time dependency only;
# it is NOT linked into the nextpnr binaries.
if test ! -d prjtrellis; then
    git clone https://github.com/YosysHQ/prjtrellis
    if test $? -ne 0; then exit 1; fi
fi
git config --global --add safe.directory "${proj}/prjtrellis" 2>/dev/null || true
cd "${proj}/prjtrellis"
git submodule update --init --recursive
if test $? -ne 0; then exit 1; fi
# Out-of-tree build; force lib (not lib64) so FindTrellis.cmake can find
# pytrellis under $TRELLIS_INSTALL_PREFIX/lib/trellis/ on all platforms.
mkdir -p libtrellis/build
cd libtrellis/build
cmake .. \
    -DCMAKE_INSTALL_PREFIX="${deps_prefix}" \
    -DCMAKE_INSTALL_LIBDIR=lib
if test $? -ne 0; then exit 1; fi
make -j$(nproc)
if test $? -ne 0; then exit 1; fi
make install
if test $? -ne 0; then exit 1; fi
cd "${proj}"

# pytrellis.so must be on LD_LIBRARY_PATH and PYTHONPATH so that nextpnr's
# CMake configure step can import it when generating the ECP5/MachXO2 chipdb.
export LD_LIBRARY_PATH="${deps_prefix}/lib/trellis${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
export PYTHONPATH="${deps_prefix}/lib/trellis${PYTHONPATH:+:${PYTHONPATH}}"

# ── Clone Mistral ─────────────────────────────────────────────────────────────
# The 'nextpnr-latest' branch has the API compatible with current nextpnr.
# Mistral is NOT installed separately; nextpnr's CMake adds it as a
# subdirectory (add_subdirectory) and compiles it inline, embedding the
# Cyclone V chipdb directly into the nextpnr-mistral binary.
if test ! -d mistral; then
    git clone -b nextpnr-latest https://github.com/Ravenslofty/mistral
    if test $? -ne 0; then exit 1; fi
fi
git config --global --add safe.directory "${proj}/mistral" 2>/dev/null || true

# ── Clone Project Peppercorn ──────────────────────────────────────────────────
# Peppercorn is also NOT installed; nextpnr's CMake reads device database
# files directly from the source checkout at configure time to generate the
# GateMate chipdb compiled into nextpnr-himbaechel-gatemate.
if test ! -d prjpeppercorn; then
    git clone https://github.com/YosysHQ/prjpeppercorn
    if test $? -ne 0; then exit 1; fi
fi
git config --global --add safe.directory "${proj}/prjpeppercorn" 2>/dev/null || true

# ── Build nextpnr ─────────────────────────────────────────────────────────────
mkdir -p "${proj}/nextpnr-build"
cd "${proj}/nextpnr-build"

# Portability notes:
#
#   STATIC_BUILD=OFF          - do NOT use -static (requires glibc-static, breaks
#                               mistral's C compiler test in add_subdirectory).
#                               manylinux relies on glibc backward compatibility
#                               instead of fully-static libc linking.
#   Boost_USE_STATIC_LIBS=ON  - link Boost as .a to avoid runtime libboost_*.so deps
#   BUILD_PYTHON=OFF          - no Python embedding; avoids libpython runtime dep
#   BUILD_GUI=OFF             - no Qt; avoids libQt runtime deps
#   USE_IPO=OFF               - skip LTO to keep CI link times reasonable
#   -static-libstdc++         - embed libstdc++ into the binary; avoids version skew
#   -static-libgcc            - embed libgcc_s; same reason
#
#   All backend chipdb data is generated at build time and compiled into the
#   binaries (BBA format), so there are NO external data paths at runtime.
#
#   HIMBAECHEL_SPLIT=ON - produces separate nextpnr-himbaechel-gowin and
#                         nextpnr-himbaechel-gatemate binaries for clarity.

cmake "${proj}/nextpnr" \
    -DARCH="ice40;ecp5;machxo2;mistral;himbaechel;generic" \
    -DHIMBAECHEL_UARCH="gowin;gatemate" \
    -DHIMBAECHEL_SPLIT=ON \
    -DBUILD_GUI=OFF \
    -DBUILD_PYTHON=OFF \
    -DSTATIC_BUILD=OFF \
    -DBoost_USE_STATIC_LIBS=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_IPO=OFF \
    -DCMAKE_INSTALL_PREFIX="${release_dir}" \
    -DCMAKE_EXE_LINKER_FLAGS="-static-libstdc++ -static-libgcc" \
    -DICESTORM_INSTALL_PREFIX="${deps_prefix}" \
    -DTRELLIS_INSTALL_PREFIX="${deps_prefix}" \
    -DMISTRAL_ROOT="${proj}/mistral" \
    -DHIMBAECHEL_PEPPERCORN_PATH="${proj}/prjpeppercorn"
if test $? -ne 0; then exit 1; fi

make -j$(nproc)
if test $? -ne 0; then exit 1; fi

make install
if test $? -ne 0; then exit 1; fi

cd "${proj}"
chmod +x "${release_dir}/bin/"*

# Strip debug symbols — reduces binary sizes by ~70-80%
strip --strip-unneeded "${release_dir}/bin/"nextpnr-*

# ── Portability check ─────────────────────────────────────────────────────────
# After a static build the only acceptable dynamic deps are low-level glibc
# interfaces (libc, libm, libpthread, libdl, librt, ld-linux) and the vDSO.
# Anything else indicates a library that was not statically linked and would
# need to be bundled or the build flags adjusted.
echo ""
echo "=== Dynamic library check ==="
for bin in "${release_dir}/bin/nextpnr-"*; do
    # Acceptable dynamic deps on any modern Linux (manylinux_2_34 baseline):
    #   glibc:        libc, libm, libpthread, libdl, librt, ld-linux
    #   kernel:       linux-vdso
    #   compression:  libz (zlib), libbz2 (bzip2), liblzma (xz), libzstd
    #                 — all part of the base OS on every modern distro;
    #                   these come from Boost iostreams static lib's transitive deps.
    unexpected=$(ldd "$bin" 2>/dev/null | grep -v \
        -e "linux-vdso" \
        -e "ld-linux" \
        -e "libc\.so" \
        -e "libm\.so" \
        -e "libpthread\.so" \
        -e "libdl\.so" \
        -e "librt\.so" \
        -e "libz\.so" \
        -e "libbz2\.so" \
        -e "liblzma\.so" \
        -e "libzstd\.so" \
        || true)
    if test -n "$unexpected"; then
        echo "WARNING: $(basename $bin) has unexpected dynamic deps (may need bundling):"
        echo "$unexpected"
    else
        echo "OK: $(basename $bin)"
    fi
done

# ── Copy metadata into release tree ──────────────────────────────────────────
cp "${proj}/ivpm.yaml" "${release_dir}/"
cp "${proj}/LICENSE"   "${release_dir}/"

# ── Package tarball ───────────────────────────────────────────────────────────
mkdir -p "${root}/release"
cd "${root}/release"
tar czf "nextpnr-bin-${rls_plat}-${rls_version}.tar.gz" "nextpnr-${rls_version}"
if test $? -ne 0; then exit 1; fi

echo ""
echo "=== Built: release/nextpnr-bin-${rls_plat}-${rls_version}.tar.gz ==="
