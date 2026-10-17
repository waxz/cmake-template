# CMake workflow tools

Small, dependency-free CMake scripts for building, testing, installing, packaging and sharing C++
projects on Windows (Visual Studio, MinGW) and Linux (GCC, Clang) with the same commands.

- One command builds any CMake project: picks the generator, passes the right configuration to
  every step, runs the tests, installs, packages.
- Sensible project defaults: warnings, hardening, sanitizers, `bin/` + `lib/` layout, relocatable installs.
- Installed apps carry their DLLs / `.so` files; libraries install as `find_package()` packages.
- Third-party CMake projects built at configure time; zip / NSIS / tar.gz / deb packages via CPack.

```
cmake/
  build.cmake            configure + build + test + install + package, generator chosen automatically
  common.cmake           project defaults and target helpers (warnings, sanitizers, tests, install)
  super_build.cmake      download and build third-party CMake projects at configure time
  export_package.cmake   install a library as a find_package() package (shared and/or static)
  package.cmake          CPack: zip / NSIS installer on Windows, tar.gz / deb on Linux
demo/                    application: shared + static library, app, test, install, packages
demo_lib/                library "Calc" exported as a CMake package
demo_consumer/           application using Calc through find_package()
.github/workflows/ci.yml builds and tests all demos on Windows and Ubuntu
```

## Requirements

- CMake 3.21 or newer
- Windows: Visual Studio 2017–2026 with "Desktop development with C++", or MinGW-w64 + Ninja
- Linux: GCC or Clang, Ninja or Make (Ubuntu: `sudo apt install build-essential ninja-build cmake`)

## Quick start

All commands are run from the repository root.

```
cmake -P cmake/build.cmake -- -S demo -B demo/build
```

This picks the generator, then configures, builds and runs the tests (Release by default).

## Use in your project

Copy the `cmake/` directory into your project (or add this repository as a git submodule) and
include the modules you need:

```cmake
cmake_minimum_required(VERSION 3.21...4.1)
project(my_app VERSION 1.0.0 LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
include(common)

add_executable(my_app src/main.cpp)
target_compile_features(my_app PRIVATE cxx_std_17)
set_common_flags(my_app)
set_asan(my_app)
install_deps(my_app)

include(package)   # optional: cpack / build.cmake --package
```

```
cmake -P cmake/build.cmake -- --config Debug --prefix install
```

Use a version range in `cmake_minimum_required` (`3.21...4.1`): it enables newer CMake behavior
when available, e.g. `<PACKAGE>_ROOT` environment variables in upper case.

## build.cmake

```
cmake -P cmake/build.cmake -- [-S <src>] [-B <build>] [--config <cfg>] [--prefix <dir>]
                              [--package] [--clean] [-G <generator>] [-D<VAR>=<value>...]
```

| Option | Meaning |
|---|---|
| `-S` / `-B` | source / build directory (default `.` / `build`) |
| `--config` | `Debug`, `Release` (default), `RelWithDebInfo`, `MinSizeRel` |
| `--prefix <dir>` | install into `<dir>` after the tests |
| `--package` | create packages with CPack (project must `include(package)`) |
| `--clean` | delete the build directory first; needed to switch generators |
| `-G <name>` | use this generator instead of detecting one |
| `-D<VAR>=<value>` | passed to CMake; relative paths in `CMAKE_PREFIX_PATH`, `CMAKE_INSTALL_PREFIX`, `CMAKE_TOOLCHAIN_FILE`, `*_ROOT`, `*_DIR` are made absolute |

Generator detection:

- **Windows**: newest Visual Studio with C++ tools, e.g. `Visual Studio 18 2026 -A x64`. If the
  `cmake` you started is too old for it (e.g. CLion's), the CMake bundled with Visual Studio is used.
  Without Visual Studio: Ninja, else MinGW Makefiles (`g++` on PATH).
- **Linux**: Ninja, else Unix Makefiles.
- An existing build directory keeps the generator and `cmake` it was created with.

It always passes the configuration to every step (`--config` for build / install, `-C` for ctest),
which multi-config generators such as Visual Studio need.

## Workflows

### Build, test, install an application

```
cmake -P cmake/build.cmake -- -S demo -B demo/build --config Debug --prefix demo/install
```

`install_deps()` copies every non-system DLL / `.so` the app needs next to it, so `demo/install`
runs on its own. Add `-DENABLE_SANITIZERS=ON` for ASan + UBSan in Debug (on by default on Linux).

### Third-party dependency at configure time

```
cmake -P cmake/build.cmake -- -S demo -B demo/build -DDEMO_USE_SUPERBUILD=ON
```

`build_external_project(fmt URL ... URL_HASH ...)` downloads and builds {fmt} once into
`demo/build/_superbuild/fmt/install` (Debug and Release with Visual Studio), then `find_package(fmt)` finds it.

### Packages

```
cmake -P cmake/build.cmake -- -S demo -B demo/build --package
```

Output in `demo/build/packages`:

| Platform | Output |
|---|---|
| Windows | `cmake_tools_demo-1.0.0-Windows-AMD64.zip` with the MSVC / MinGW runtime DLLs; an NSIS `.exe` installer too if [NSIS](https://nsis.sourceforge.io) is installed |
| Ubuntu | `cmake_tools_demo-1.0.0-Linux-x86_64.tar.gz` and `cmake-tools-demo_1.0.0_amd64.deb` (installs to `/opt/cmake_tools_demo`) |

```bash
sudo apt install ./demo/build/packages/cmake-tools-demo_1.0.0_amd64.deb
/opt/cmake_tools_demo/bin/demo_app
sudo apt remove cmake-tools-demo
```

Manual equivalent: `cpack --config demo/build/CPackConfig.cmake -C Release`
(on Windows use the `cpack.exe` next to `cmake.exe`, not Chocolatey's `cpack`).

### Library as a find_package() package

Build and install Calc as shared and static into one prefix:

```
cmake -P cmake/build.cmake -- -S demo_lib -B demo_lib/build-shared --prefix out/calc
cmake -P cmake/build.cmake -- -S demo_lib -B demo_lib/build-static --prefix out/calc -DBUILD_SHARED_LIBS=OFF
```

Use it from another project:

```
cmake -P cmake/build.cmake -- -S demo_consumer -B demo_consumer/build -DCalc_ROOT=out/calc
cmake -P cmake/build.cmake -- -S demo_consumer -B demo_consumer/build-static -DCalc_ROOT=out/calc -DCALC_VARIANT=static
```

Where `find_package(Calc)` looks, first match wins:

| Setting | Use when |
|---|---|
| `-DCalc_DIR=<prefix>/lib/cmake/Calc` | pointing at one exact install |
| `-DCalc_ROOT=<prefix>` (or env var `Calc_ROOT` / `CALC_ROOT`) | per-library prefix; each package gets its own, e.g. `-DCalc_ROOT=... -DFoo_ROOT=...` |
| `-DCMAKE_PREFIX_PATH=<p1>;<p2>` | one or more prefixes searched for every package |
| nothing | demo fallback: `out/calc-<windows\|linux>`, then `out/calc` |

Changing `Calc_ROOT` on an existing build directory takes effect: the consumer drops the cached
`Calc_DIR` when it changes (with plain `find_package`, `Calc_DIR` would stay cached).
`<PKG>_ROOT` as an upper-case environment variable needs CMake 3.27+ and `cmake_minimum_required(VERSION 3.21...4.1)`
(a version range, as in the demos).

```cmake
find_package(Calc 1.0 REQUIRED)                      # shared if installed, else static
find_package(Calc 1.0 REQUIRED COMPONENTS static)    # or -DCalc_SHARED_LIBS=OFF
target_link_libraries(app PRIVATE Calc::calc)
```

Debug builds install with a `d` postfix (`calcd.dll`) next to Release. Use a separate prefix per
platform (`out/calc-windows`, `out/calc-linux`): both write `lib/cmake/Calc`.

## CMake modules

Include order:

```cmake
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
include(common)          # after project()
include(super_build)     # optional
include(export_package)  # optional, libraries
# ... targets and install() rules ...
include(package)         # optional, last
```

### common.cmake

Defaults: `Debug` build type, no compiler extensions, executables and DLLs in `bin/`, libraries in
`lib/`, installed executables find `../lib` through the RPATH (Linux / macOS).

| Function / option | Purpose |
|---|---|
| `set_common_flags(<target>)` | warnings (`/W4`, `-Wall -Wextra ...`) and hardening |
| `set_asan(<target>)` | ASan + UBSan in Debug when `ENABLE_SANITIZERS` is ON |
| `set_test(<target>)` | links GTest / Catch2 / doctest if found, sanitizers, `add_test()` |
| `copy_to_target_dir(<target> [SUBDIR d] FILES ...)` | copy files next to the target's output (per config) |
| `copy_runtime_dlls(<target>)` | Windows: copy DLLs of linked packages next to the exe |
| `install_deps(<exe> [DIRECTORIES ...])` | install the exe and every non-system DLL / `.so` it needs |
| `ENABLE_SANITIZERS` | default ON on Linux, OFF on Windows |
| `ENABLE_HARDENING` | stack protector, CET, Control Flow Guard, RELRO; default ON |

### super_build.cmake

```cmake
build_external_project(<name>
    URL <url> URL_HASH SHA256=<hash> | GIT_REPOSITORY <url> GIT_TAG <tag>
    [CMAKE_ARGS -DVAR=value ...])
find_package(<name> CONFIG REQUIRED)
```

Built with the same generator and compiler, skipped on later configures while unchanged.
Delete `<build>/_superbuild/<name>` to rebuild.

### export_package.cmake

```cmake
install_package(<Package>
    TARGETS <target>...
    [NAMESPACE <ns>::]              # default <Package>::
    [COMPATIBILITY <mode>]          # default SameMajorVersion
    [DEPENDENCIES "Threads" ...]    # find_dependency() for consumers (needed by static libs)
    [INCLUDE_DIRS <dir>...])        # header trees installed to include/
```

Installs `lib/cmake/<Package>/<Package>Config.cmake`, `...ConfigVersion.cmake` and the targets.
See [`demo_lib/CMakeLists.txt`](demo_lib/CMakeLists.txt) for export headers, `DEBUG_POSTFIX` and
the Windows static library name.

### package.cmake

`include(package)` after the `install()` rules. Set before it if needed: `CPACK_PACKAGE_CONTACT`
(`"Name <email>"`, required for `.deb`), `CPACK_PACKAGE_VENDOR`, `CPACK_PACKAGE_DESCRIPTION_SUMMARY`,
`CPACK_DEBIAN_INSTALL_PREFIX` (default `/opt/<name>`), `CPACK_GENERATOR`.

## Setup

### Windows: use the CMake that ships with Visual Studio

`Visual Studio 18 2026` needs CMake 4.2+ or the CMake bundled with Visual Studio 2026.
Older ones (e.g. the CMake bundled with CLion) fail with
`Could not create named generator Visual Studio 18 2026`.
`build.cmake` switches to the Visual Studio CMake on its own; this matters when you run `cmake` by hand.

**Current terminal only** (PowerShell):

```powershell
$env:Path = "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;" + $env:Path
cmake --version            # expect: cmake version 4.x.x-msvc...
```

Command Prompt (`cmd.exe`):

```bat
set "PATH=C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;%PATH%"
```

**Permanently** (current user, PowerShell; puts it in front of other CMakes):

```powershell
$vsCMake = "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($userPath -split ";") -notcontains $vsCMake) {
    [Environment]::SetEnvironmentVariable("Path", "$vsCMake;$userPath", "User")
}
```

or: Start → "Edit environment variables for your account" → `Path` → New → Move Up.
Avoid `setx PATH ...`: it truncates long paths at 1024 characters.

Tips:

- **Restart the editor completely** (close every window) after a permanent change. Terminals
  inside VS Code / CLion inherit the PATH the editor started with; a new terminal tab is not enough.
- **Check which CMake wins**: `where.exe cmake` (first line is used) or `Get-Command cmake -All`.
- **Edition / version**: replace `18\Community` with your install, e.g. `18\Professional`,
  `18\Enterprise`, or `2022\Community` for Visual Studio 2022. List installs with:
  `& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -property installationPath`
- **Developer PowerShell for VS 2026** (Start menu) already has this CMake, `cl`, and `ninja` on PATH.
- **CLion ignores PATH** for CMake: set it in Settings → Build, Execution, Deployment → Toolchains.
- **Long paths**: MSVC fails with error C1041 / C1083 when paths exceed 260 characters; keep build
  directories short, especially with `build_external_project()`.

### Ubuntu

```bash
sudo apt install build-essential ninja-build cmake
cmake --version            # Ubuntu 24.04's apt CMake is 3.28; enough (needs 3.21+)
```

A newer CMake installed under `/opt` or `~/.local` goes in front of PATH (add to `~/.bashrc`):

```bash
export PATH="/opt/cmake-4.3.1/bin:$PATH"
```

### IDEs

[`demo/CMakePresets.json`](demo/CMakePresets.json) has configure / build / test presets
(`vs2026`, `vs2022`, `ninja-msvc`, `ninja`) for Visual Studio, VS Code (CMake Tools) and CLion:

```
cmake --workflow --preset vs2026-release
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Could not create named generator Visual Studio 18 2026` | old `cmake` on PATH; see Setup, or use `build.cmake` |
| `generator ... does not match the generator used previously` | `--clean`, or delete the build directory |
| ctest `Not Run` / install `cannot find .../Release/...` | Visual Studio: pass the same `--config` / `-C` to every step (`build.cmake` does) |
| `Could not find a package configuration file provided by "Calc"` | install `demo_lib` first; pass its prefix with `-DCalc_ROOT` / `-DCMAKE_PREFIX_PATH` (absolute when calling `cmake` directly) |
| `The static variant of Calc is not installed` | build `demo_lib` with `-DBUILD_SHARED_LIBS=OFF` into the same prefix |
| `LNK2038 mismatch detected for 'RuntimeLibrary'` | Debug app linking a Release-only library; install the library's Debug build too |
| `LNK2038 mismatch detected for 'annotate_string'` / `'annotate_vector'` / `'annotate_optional'` | MSVC ASan target linking a non-ASan library; use `set_asan()`, which defines `_DISABLE_STL_ANNOTATION` |

## Continuous integration

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on every push and pull request, on
`windows-latest` (Visual Studio) and `ubuntu-latest` (GCC + Ninja):

1. `demo` in Debug with sanitizers and the {fmt} superbuild, installed and run
2. `demo` in Release with packages (uploaded as workflow artifacts)
3. `demo_lib` shared and static into one prefix
4. `demo_consumer` against both variants via `Calc_ROOT`

## License

[MIT](LICENSE). See [CHANGELOG.md](CHANGELOG.md) for release notes.
