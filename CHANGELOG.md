# Changelog

## 1.0.0

First release.

- `cmake/build.cmake`: configure, build, test, install and package with an automatically chosen
  generator (newest Visual Studio, Ninja, MinGW Makefiles or Unix Makefiles); falls back to the CMake
  bundled with Visual Studio when the running CMake is too old for it.
- `cmake/common.cmake`: project defaults (output layout, RPATH), warnings and hardening, sanitizers,
  test helper, per-config file copies, runtime DLL copies, `install_deps()`.
- `cmake/super_build.cmake`: `build_external_project()` builds third-party CMake projects at
  configure time (Debug and Release with Visual Studio).
- `cmake/export_package.cmake`: `install_package()` installs a library as a `find_package()`
  package with shared and static variants side by side.
- `cmake/package.cmake`: CPack setup for zip / NSIS on Windows and tar.gz / deb on Linux.
- Demos: `demo`, `demo_lib`, `demo_consumer`; GitHub Actions CI on Windows and Ubuntu.
