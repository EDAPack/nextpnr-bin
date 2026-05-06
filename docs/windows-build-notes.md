# Windows Build Notes

## Summary

Building nextpnr with a native Windows toolchain (MSVC / Clang-CL) is **not currently viable**
without substantial upstream patches. This document records findings from an attempted CI build
using `clang-cl` + `lld-link` + `vcpkg` on a `windows-2022` GitHub Actions runner.

## Upstream status

nextpnr's own CI (`YosysHQ/nextpnr`, `.github/workflows/arch_ci.yml`) is 100% Linux (Ubuntu).
There are no Windows jobs, no MSVC CMake presets, and no accommodation for COFF/PE object format.
Community Windows builds (e.g. OSS CAD Suite) go through **MSYS2 / MinGW-w64**, which provides
a POSIX-compatible layer and a GCC/GNU-ld toolchain.

## Issues encountered (Clang-CL / lld-link path)

### 1. `lzma.h` not found
`mistral/generator/CMakeLists.txt` uses a raw `target_link_libraries(generator PUBLIC lzma)`
instead of the vcpkg-imported `LibLZMA::LibLZMA` target, so include and library paths are not
propagated automatically. Worked around by injecting `/I<vcpkg-include>` into `CMAKE_CXX_FLAGS`
and `/LIBPATH:<vcpkg-lib>` into `CMAKE_EXE_LINKER_FLAGS`.

### 2. `/EHsc` dropped
Setting `CMAKE_CXX_FLAGS` from the command line replaces CMake's default MSVC init flags
(`/DWIN32 /D_WINDOWS /EHsc`). Those defaults must be re-stated explicitly.

### 3. `strcasecmp` undeclared
`mistral/libmistral/cyclonev.h` uses `strcasecmp` (POSIX). MSVC has `_stricmp` instead.
Worked around with `/Dstrcasecmp=_stricmp` compiler flag.

### 4. `OUT` / `IN` macro conflicts
Windows SDK (`windef.h`) defines `OUT` and `IN` as empty SAL-annotation macros.
`mistral/libmistral/cv-porttypes.ipp` uses `OUT` and `IN` as enum member names.
`/UOUT /UIN` on the command line doesn't help because system headers redefine them later.
Fix requires `#pragma push_macro("OUT") / #undef OUT / ... / #pragma pop_macro("OUT")`
wrapped around the `#include "cv-porttypes.ipp"` line in `cyclonev.h`.

### 5. `int` vs `int64_t` (`long` width)
On Windows `long` is 32-bit even on x64; `int64_t` is `long long`.
`nextpnr/mistral/pack.cc` used `8L`, `9L`, etc. as `int64_t` literals, causing
`std::max<int64_t>` type-mismatch errors. Fixed by changing to `8LL`, `9LL`, etc.

### 6. Binary resource embedding — **fundamental blocker**
`mistral/libmistral/CMakeLists.txt` embeds Cyclone V routing data (`.bin` files) as
linkable symbols using the GNU linker's binary input mode:

```cmake
add_custom_command(
   OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/cvd-${die}-r.o
   WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
   COMMAND ld -r -b binary -o cvd-${die}-r.o ${die}-r.bin
   DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${die}-r.bin
)
```

This produces ELF `.o` files with symbols `_binary_<name>_bin_start` / `_binary_<name>_bin_end`.
The technique is **ELF / GNU ld specific** — `lld-link` (COFF) cannot produce or consume these.

All seven Cyclone V die variants (`e50f`, `gx25f`, `gt75f`, `gt150f`, `gt300f`, `sx50f`, `sx120f`)
plus a `global.bin` file are embedded this way, so the `mistral` backend simply cannot link on
Windows without either:

- Patching `CMakeLists.txt` to use `llvm-objcopy -I binary -O pe-x86-64 -B i386:x86-64`
  (produces COFF output; ships in `%VCINSTALLDIR%\Tools\Llvm\x64\bin\`), **or**
- Replacing the binary embedding with a pure C++ approach (incbin, xxd-generated headers, etc.)

Neither fix is upstream; both require patching mistral's CMakeLists before the nextpnr cmake
configure step.

## Recommended approach for Windows

Use **MSYS2 / MinGW-w64** (as OSS CAD Suite does). This avoids all of the above issues:
- GNU ld is available → binary embedding works natively
- POSIX headers are present → `strcasecmp`, etc. resolve
- No SAL macro conflicts
- No `long` width issues

A GitHub Actions job using `msys2/setup-msys2@v2` with the `MINGW64` environment is the
community-proven path. The existing `scripts/build.sh` may work with minimal changes inside
that environment.

## Artifacts

`scripts/build_windows.ps1` was created during this investigation. It contains all the
Clang-CL CMake flags and patch steps accumulated above. It is left in the repo as a
reference but is **not wired into CI**. Delete or repurpose it when a working Windows
build strategy is chosen.

The `ci-windows` job in `.github/workflows/ci.yml` is present but not enabled (the
Linux jobs were commented out while iterating; restore them and remove the Windows job
to return to the pre-investigation state).
