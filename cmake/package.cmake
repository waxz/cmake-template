# package.cmake - CPack setup. include(package) at the end of CMakeLists.txt, after the install() rules.
# Packages contain exactly what `cmake --install` installs.
#
#   cmake -P cmake/build.cmake -- -S . -B build --package          (or: cpack --config build/CPackConfig.cmake -C Release)
#
# Output in <build>/packages:
#   Windows  .zip, plus an .exe installer when NSIS (makensis) is installed. The MSVC runtime is
#            bundled so the package runs on machines without Visual Studio.
#   Linux    .tar.gz, plus a .deb (installs to /opt/<name>, dependencies detected) when dpkg-deb exists.
#   Override with -DCPACK_GENERATOR="ZIP;NSIS" etc.
#
# Set before include() to override: CPACK_PACKAGE_VENDOR, CPACK_PACKAGE_CONTACT ("Name <email>",
# required for .deb), CPACK_PACKAGE_DESCRIPTION_SUMMARY, CPACK_DEBIAN_INSTALL_PREFIX (default /opt/<name>), ...

include_guard(GLOBAL)
include(GNUInstallDirs)

if(NOT DEFINED CPACK_GENERATOR)
    if(WIN32)
        set(CPACK_GENERATOR ZIP)
        set(_ct_pf86 "ProgramFiles(x86)")
        find_program(MAKENSIS_EXECUTABLE makensis PATHS "$ENV{ProgramFiles}/NSIS" "$ENV{${_ct_pf86}}/NSIS")
        if(MAKENSIS_EXECUTABLE)
            list(APPEND CPACK_GENERATOR NSIS)
        endif()
    else()
        set(CPACK_GENERATOR TGZ)
        find_program(DPKG_DEB_EXECUTABLE dpkg-deb)
        if(DPKG_DEB_EXECUTABLE)
            list(APPEND CPACK_GENERATOR DEB)
        endif()
    endif()
endif()

# Metadata (each can be set before include())
set(_ct_defaults
        CPACK_PACKAGE_NAME "${PROJECT_NAME}"
        CPACK_PACKAGE_VERSION "${PROJECT_VERSION}"
        CPACK_PACKAGE_VENDOR "${PROJECT_NAME}"
        CPACK_PACKAGE_CONTACT "${PROJECT_NAME} maintainers <noreply@example.com>"
        CPACK_PACKAGE_DESCRIPTION_SUMMARY "${PROJECT_NAME}"
        CPACK_PACKAGE_INSTALL_DIRECTORY "${PROJECT_NAME}"
        CPACK_PACKAGE_DIRECTORY "${PROJECT_BINARY_DIR}/packages")
while(_ct_defaults)
    list(POP_FRONT _ct_defaults _ct_var _ct_value)
    if(NOT DEFINED ${_ct_var})
        set(${_ct_var} "${_ct_value}")
    endif()
endwhile()
if(PROJECT_DESCRIPTION AND CPACK_PACKAGE_DESCRIPTION_SUMMARY STREQUAL PROJECT_NAME)
    set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${PROJECT_DESCRIPTION}")
endif()
if(NOT DEFINED CPACK_RESOURCE_FILE_LICENSE)
    foreach(_ct_license LICENSE LICENSE.txt LICENSE.md)
        if(EXISTS "${PROJECT_SOURCE_DIR}/${_ct_license}")
            set(CPACK_RESOURCE_FILE_LICENSE "${PROJECT_SOURCE_DIR}/${_ct_license}")
            break()
        endif()
    endforeach()
endif()

# <name>-<version>-<os>-<arch>, e.g. demo-1.0.0-Windows-AMD64.zip
if(NOT DEFINED CPACK_PACKAGE_FILE_NAME)
    set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}-${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}")
endif()
set(CPACK_STRIP_FILES ON) # Linux: strip debug info from release packages
set(CPACK_VERBATIM_VARIABLES ON)

# Windows: ship the MSVC runtime (vcruntime / msvcp) next to the executables
if(MSVC)
    # (the Universal CRT is part of Windows 10+, so it is not bundled)
    set(CMAKE_INSTALL_SYSTEM_RUNTIME_DESTINATION ${CMAKE_INSTALL_BINDIR})
    include(InstallRequiredSystemLibraries)
endif()

# NSIS installer
set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL ON)
set(CPACK_NSIS_MODIFY_PATH ON) # offer to add <install dir>/bin to PATH

# Debian package: self-contained under /opt/<name>; the RPATH ($ORIGIN/../lib) finds its libraries.
# Set per generator at cpack time, so archives (zip / tar.gz) keep a plain bin/ lib/ include/ layout.
if(NOT DEFINED CPACK_DEBIAN_INSTALL_PREFIX)
    set(CPACK_DEBIAN_INSTALL_PREFIX "/opt/${CPACK_PACKAGE_NAME}")
endif()
set(CPACK_PROJECT_CONFIG_FILE "${PROJECT_BINARY_DIR}/CPackProjectConfig.cmake")
file(WRITE "${CPACK_PROJECT_CONFIG_FILE}" [[
if(CPACK_GENERATOR STREQUAL "DEB")
    set(CPACK_PACKAGING_INSTALL_PREFIX "${CPACK_DEBIAN_INSTALL_PREFIX}")
endif()
]])
if(NOT DEFINED CPACK_DEBIAN_PACKAGE_NAME) # Debian names: lowercase, digits, + - . only
    string(TOLOWER "${CPACK_PACKAGE_NAME}" CPACK_DEBIAN_PACKAGE_NAME)
    string(REGEX REPLACE "[^a-z0-9.+-]" "-" CPACK_DEBIAN_PACKAGE_NAME "${CPACK_DEBIAN_PACKAGE_NAME}")
endif()
set(CPACK_DEBIAN_FILE_NAME DEB-DEFAULT) # <name>_<version>_<arch>.deb
find_program(DPKG_SHLIBDEPS_EXECUTABLE dpkg-shlibdeps)
if(DPKG_SHLIBDEPS_EXECUTABLE)
    set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON) # Depends: libc6, libstdc++6, ... computed from the binaries
endif()

include(CPack)
