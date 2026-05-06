# Build script for nextpnr-bin on Windows.
#
# Uses Clang-CL (LLVM front-end with MSVC ABI) via Visual Studio 2022 + Ninja.
# Boost and Eigen3 come from vcpkg (x64-windows-static triplet).
#
# Backends built: ice40, mistral, himbaechel (gowin + gatemate), generic
#   ecp5 / machxo2 are skipped on Windows because they require pytrellis
#   (a Python C-extension built from Project Trellis libtrellis), which
#   adds significant build complexity. They can be enabled once pytrellis
#   builds cleanly under Clang-CL.
#
# Prerequisites (all present on the GitHub Actions windows-2022 runner after
# ilammy/msvc-dev-cmd sets up the VS developer environment):
#   - Visual Studio 2022 with LLVM / Clang-CL component
#   - cmake, ninja, git, python3 in PATH
#   - vcpkg at C:\vcpkg
#
# Override env vars:
#   nextpnr_version  - version string (default: 0.0.1)
#   rls_plat         - platform tag   (default: windows-x64)

$ErrorActionPreference = "Stop"

$proj = $PWD.Path
$rls_version = if ($env:nextpnr_version) { $env:nextpnr_version } else { "0.0.1" }
$rls_plat    = if ($env:rls_plat)        { $env:rls_plat }        else { "windows-x64" }

$deps_prefix = "$proj\deps-install"
$release_dir = "$proj\release\nextpnr-$rls_version"
$vcpkg_root  = "C:\vcpkg"
$triplet     = "x64-windows-static"

New-Item -ItemType Directory -Force $deps_prefix       | Out-Null
New-Item -ItemType Directory -Force "$release_dir\bin" | Out-Null

# ── Locate clang-cl ───────────────────────────────────────────────────────────
# After ilammy/msvc-dev-cmd the VCINSTALLDIR env var points at the VC root.
# Clang-CL lives under VC\Tools\Llvm\x64\bin\.
if ($env:VCINSTALLDIR) {
    $llvm_bin = "$env:VCINSTALLDIR\Tools\Llvm\x64\bin"
} else {
    # Fallback: search common VS2022 paths
    $llvm_bin = "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Tools\Llvm\x64\bin"
    if (!(Test-Path $llvm_bin)) {
        $llvm_bin = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\Llvm\x64\bin"
    }
}
$clang_cl  = "$llvm_bin\clang-cl.exe"
$clang_cpp = "$llvm_bin\clang-cl.exe"   # clang-cl handles both C and C++
$lld_link  = "$llvm_bin\lld-link.exe"

if (!(Test-Path $clang_cl)) {
    Write-Error "clang-cl not found at $clang_cl"
    exit 1
}
Write-Host "=== Using clang-cl: $clang_cl ==="
& $clang_cl --version

# ── vcpkg dependencies ────────────────────────────────────────────────────────
Write-Host "=== Installing vcpkg dependencies ($triplet) ==="
& "$vcpkg_root\vcpkg.exe" install `
    boost-filesystem `
    boost-program-options `
    boost-iostreams `
    boost-thread `
    boost-system `
    boost-date-time `
    boost-regex `
    eigen3 `
    --triplet $triplet `
    --no-print-usage
if ($LASTEXITCODE -ne 0) { Write-Error "vcpkg install failed"; exit 1 }

# ── Python build-time dependencies ───────────────────────────────────────────
Write-Host "=== Installing Python build-time dependencies ==="
python -m pip install intervaltree apycula --quiet
if ($LASTEXITCODE -ne 0) { Write-Error "pip install failed"; exit 1 }

# Capture the exact Python interpreter that has apycula so we can pass it
# to cmake as Python3_EXECUTABLE.  Without this cmake may pick up a different
# Python on the runner that doesn't have apycula installed.
$python_exe = (python -c "import sys; print(sys.executable)").Trim()
Write-Host "=== Using Python: $python_exe ==="

# ── Clone nextpnr ─────────────────────────────────────────────────────────────
Write-Host "=== Cloning nextpnr ==="
if (!(Test-Path "nextpnr")) {
    git clone https://github.com/YosysHQ/nextpnr
    if ($LASTEXITCODE -ne 0) { Write-Error "git clone nextpnr failed"; exit 1 }
}
Push-Location nextpnr
git submodule update --init
if ($LASTEXITCODE -ne 0) { Write-Error "git submodule update failed"; exit 1 }
Pop-Location

# ── IceStorm chipdb ───────────────────────────────────────────────────────────
# On Linux, icestorm's chipdb-*.txt and timings_*.txt files are produced by
# running `make install` (which invokes Python to generate timing models).
# On Windows, make is not readily available and icestorm has no CMake build.
# ice40 is excluded from the Windows ARCH list until we have a proper icestorm
# build step here (e.g. via chocolatey make + Git Bash).
Write-Host "=== IceStorm: skipped on Windows (ice40 not in ARCH) ==="

# ── Clone Mistral ─────────────────────────────────────────────────────────────
# nextpnr-latest branch has the API compatible with current nextpnr.
# Mistral is NOT installed separately — nextpnr CMake adds it via
# add_subdirectory() and compiles the Cyclone V chipdb into the binary.
Write-Host "=== Cloning Mistral ==="
if (!(Test-Path "mistral")) {
    git clone -b nextpnr-latest https://github.com/Ravenslofty/mistral
    if ($LASTEXITCODE -ne 0) { Write-Error "git clone mistral failed"; exit 1 }
}

# ── Clone Project Peppercorn ──────────────────────────────────────────────────
Write-Host "=== Cloning Project Peppercorn ==="
if (!(Test-Path "prjpeppercorn")) {
    git clone https://github.com/YosysHQ/prjpeppercorn
    if ($LASTEXITCODE -ne 0) { Write-Error "git clone prjpeppercorn failed"; exit 1 }
}

# ── Configure nextpnr ─────────────────────────────────────────────────────────
Write-Host "=== Configuring nextpnr ==="
New-Item -ItemType Directory -Force "$proj\nextpnr-build" | Out-Null
Push-Location "$proj\nextpnr-build"

# Forward-slash paths for cmake on Windows
$deps_fwd    = $deps_prefix  -replace '\\','/'
$release_fwd = $release_dir  -replace '\\','/'
$proj_fwd    = $proj         -replace '\\','/'
$vcpkg_fwd   = $vcpkg_root   -replace '\\','/'

# Notes on flags:
#   -G Ninja + clang-cl  : avoids MSBuild; clang-cl is the MSVC-ABI Clang front-end
#   STATIC_BUILD=OFF     : full -static not used; instead link CRT statically via /MT
#   Boost_USE_STATIC_LIBS: link Boost .lib files from vcpkg x64-windows-static
#   BUILD_PYTHON=OFF     : no Python embedding
#   BUILD_GUI=OFF        : no Qt
#   ARCH skips ecp5/machxo2 (need pytrellis Python extension — add later)
cmake "$proj_fwd/nextpnr" `
    -G Ninja `
    -DCMAKE_BUILD_TYPE=Release `
    -DCMAKE_C_COMPILER="$clang_cl" `
    -DCMAKE_CXX_COMPILER="$clang_cl" `
    -DCMAKE_LINKER="$lld_link" `
    -DCMAKE_TOOLCHAIN_FILE="$vcpkg_fwd/scripts/buildsystems/vcpkg.cmake" `
    -DVCPKG_TARGET_TRIPLET="$triplet" `
    -DPython3_EXECUTABLE="$python_exe" `
    -DARCH="mistral;himbaechel;generic" `
    -DHIMBAECHEL_UARCH="gowin;gatemate" `
    -DHIMBAECHEL_SPLIT=ON `
    -DBUILD_GUI=OFF `
    -DBUILD_PYTHON=OFF `
    -DSTATIC_BUILD=OFF `
    -DBoost_USE_STATIC_LIBS=ON `
    -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded `
    -DUSE_IPO=OFF `
    "-DCMAKE_CXX_FLAGS=/DWIN32 /D_WINDOWS /EHsc /I$vcpkg_fwd/installed/$triplet/include" `
    "-DCMAKE_C_FLAGS=/DWIN32 /D_WINDOWS /I$vcpkg_fwd/installed/$triplet/include" `
    -DCMAKE_INSTALL_PREFIX="$release_fwd" `
    -DMISTRAL_ROOT="$proj_fwd/mistral" `
    -DHIMBAECHEL_PEPPERCORN_PATH="$proj_fwd/prjpeppercorn"

if ($LASTEXITCODE -ne 0) { Write-Error "cmake configure failed"; exit 1 }

# ── Build nextpnr ─────────────────────────────────────────────────────────────
Write-Host "=== Building nextpnr ==="
cmake --build . --parallel
if ($LASTEXITCODE -ne 0) { Write-Error "cmake build failed"; exit 1 }

cmake --install .
if ($LASTEXITCODE -ne 0) { Write-Error "cmake install failed"; exit 1 }

Pop-Location

# ── Copy metadata into release tree ──────────────────────────────────────────
Copy-Item -Force "$proj\ivpm.yaml" "$release_dir\"
Copy-Item -Force "$proj\LICENSE"   "$release_dir\"

# ── Package zip ───────────────────────────────────────────────────────────────
Write-Host "=== Packaging ==="
New-Item -ItemType Directory -Force "$proj\release" | Out-Null
Push-Location "$proj\release"
$zip_name = "nextpnr-bin-$rls_plat-$rls_version.zip"
if (Test-Path $zip_name) { Remove-Item $zip_name }
# Use tar (available on Windows 2019+) for consistent behaviour
tar -czf $zip_name "nextpnr-$rls_version"
if ($LASTEXITCODE -ne 0) { Write-Error "tar failed"; exit 1 }
Pop-Location

Write-Host ""
Write-Host "=== Built: release\nextpnr-bin-$rls_plat-$rls_version.zip ==="
