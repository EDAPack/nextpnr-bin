#!/usr/bin/env bash
# nextpnr-bin build driver.
#
# Builds nextpnr (ice40, ecp5, machxo2, mistral, himbaechel gowin+gatemate,
# generic) from the exact commits resolved by edapack-common's resolve-inputs.py
# and emits a release manifest. Non-standard deps (icestorm chipdb, prjtrellis,
# mistral, prjpeppercorn) are cloned at their resolved commits and built/embedded
# so the nextpnr-* binaries are portable.
#
# Runs in CI (reusable workflow) and locally (local-build.sh). All transient
# state goes to WORK_DIR; tarball + manifest land in OUT_DIR; the source tree is
# never written to.
set -euo pipefail

# --- locate edapack-common --------------------------------------------------
if [ -z "${EC_COMMON:-}" ]; then
    _cand="$(cd "$(dirname "$0")/../../edapack-common" 2>/dev/null && pwd || true)"
    [ -n "$_cand" ] && EC_COMMON="$_cand"
fi
if [ -z "${EC_COMMON:-}" ] || [ ! -f "$EC_COMMON/scripts/build-common.sh" ]; then
    echo "ERROR: edapack-common not found. Set EC_COMMON or place edapack-common beside nextpnr-bin." >&2
    exit 1
fi
# shellcheck source=/dev/null
source "$EC_COMMON/scripts/build-common.sh"

: "${EC_PACKAGE:=nextpnr-bin}"
export EC_PACKAGE
ec_init_dirs
ec_prepare_candidate

os="$(uname -s)"
plat="${EC_IMAGE_NAME:-manylinux_2_34_x86_64}"

# Degraded-mode dependency install (prebaked image already has the toolchain
# and the intervaltree/apycula chipdb generators).
if [ "${EC_INSTALL_DEPS:-0}" = "1" ] && [ "$os" = "Linux" ]; then
    yum install -y cmake python3-devel boost-devel boost-static eigen3-devel \
        libffi-devel zlib-devel xz-devel bzip2-devel libzstd-devel gcc-c++ git make pkg-config || true
    pip install --quiet "cmake<3.30" intervaltree apycula || true
fi

deps_prefix="$WORK_DIR/deps-install"
release_root="$WORK_DIR/release/nextpnr"
rm -rf "$deps_prefix" "$release_root"
mkdir -p "$deps_prefix" "$release_root/bin"

njobs="$(nproc 2>/dev/null || echo 4)"

# --- clone resolved inputs --------------------------------------------------
nextpnr_src="$(ec_clone_input nextpnr "$(ec_input_get nextpnr repo)" "$(ec_input_get nextpnr resolved_sha)")"
icestorm_src="$(ec_clone_input icestorm "$(ec_input_get icestorm repo)" "$(ec_input_get icestorm resolved_sha)")"
trellis_src="$(ec_clone_input prjtrellis "$(ec_input_get prjtrellis repo)" "$(ec_input_get prjtrellis resolved_sha)")"
mistral_src="$(ec_clone_input mistral "$(ec_input_get mistral repo)" "$(ec_input_get mistral resolved_sha)")"
peppercorn_src="$(ec_clone_input prjpeppercorn "$(ec_input_get prjpeppercorn repo)" "$(ec_input_get prjpeppercorn resolved_sha)")"

# --- IceStorm chipdb (no iceprog; just the share/icebox data) ---------------
make -C "$icestorm_src" -j"$njobs" ICEPROG=0 PREFIX="$deps_prefix"
make -C "$icestorm_src" install ICEPROG=0 PREFIX="$deps_prefix"

# --- Project Trellis (pytrellis, build-time chipdb generator) ---------------
mkdir -p "$trellis_src/libtrellis/build"
cmake -S "$trellis_src/libtrellis" -B "$trellis_src/libtrellis/build" \
    -DCMAKE_INSTALL_PREFIX="$deps_prefix" -DCMAKE_INSTALL_LIBDIR=lib
make -C "$trellis_src/libtrellis/build" -j"$njobs"
make -C "$trellis_src/libtrellis/build" install
export LD_LIBRARY_PATH="$deps_prefix/lib/trellis${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
export PYTHONPATH="$deps_prefix/lib/trellis${PYTHONPATH:+:${PYTHONPATH}}"

# --- nextpnr (mistral + peppercorn compiled/read inline; see flags) ---------
build_dir="$WORK_DIR/nextpnr-build"
rm -rf "$build_dir"; mkdir -p "$build_dir"
cmake -S "$nextpnr_src" -B "$build_dir" \
    -DARCH="ice40;ecp5;machxo2;mistral;himbaechel;generic" \
    -DHIMBAECHEL_UARCH="gowin;gatemate" \
    -DHIMBAECHEL_SPLIT=ON \
    -DBUILD_GUI=OFF \
    -DBUILD_PYTHON=OFF \
    -DSTATIC_BUILD=OFF \
    -DBoost_USE_STATIC_LIBS=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_IPO=OFF \
    -DCMAKE_INSTALL_PREFIX="$release_root" \
    -DCMAKE_EXE_LINKER_FLAGS="-static-libstdc++ -static-libgcc" \
    -DICESTORM_INSTALL_PREFIX="$deps_prefix" \
    -DTRELLIS_INSTALL_PREFIX="$deps_prefix" \
    -DMISTRAL_ROOT="$mistral_src" \
    -DHIMBAECHEL_PEPPERCORN_PATH="$peppercorn_src"
make -C "$build_dir" -j"$njobs"
make -C "$build_dir" install

chmod +x "$release_root/bin/"* 2>/dev/null || true
strip --strip-unneeded "$release_root/bin/"nextpnr-* 2>/dev/null || true

# --- portability check (static build: only low-level glibc deps allowed) ----
ec_log "dynamic library check"
for bin in "$release_root/bin/nextpnr-"*; do
    [ -e "$bin" ] || continue
    unexpected=$(ldd "$bin" 2>/dev/null | grep -v \
        -e "linux-vdso" -e "ld-linux" -e "libc\.so" -e "libm\.so" \
        -e "libpthread\.so" -e "libdl\.so" -e "librt\.so" \
        -e "libz\.so" -e "libbz2\.so" -e "liblzma\.so" -e "libzstd\.so" || true)
    if [ -n "$unexpected" ]; then
        ec_log "WARNING: $(basename "$bin") has unexpected dynamic deps:"
        echo "$unexpected"
    fi
done

# --- metadata + shared release tail -----------------------------------------
cp "$SRC_DIR/ivpm.yaml" "$release_root/" 2>/dev/null || true
cp "$SRC_DIR/LICENSE"   "$release_root/" 2>/dev/null || true
ec_finalize_release "$SRC_DIR" "$release_root" "$CANDIDATE_JSON"
tarball="nextpnr-bin-${plat}-${EC_VERSION}.tar.gz"
ec_make_tarball "$release_root" "$tarball"
ec_log "build complete: $tarball"
