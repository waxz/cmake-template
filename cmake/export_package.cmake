# export_package.cmake - install library targets as a CMake package, so other projects can use
#   find_package(<Package>) + target_link_libraries(app PRIVATE <Package>::<target>)
#
#   install_package(<Package>
#       TARGETS <target>...                    targets to install and export
#       [NAMESPACE <ns>]                       default: <Package>::
#       [COMPATIBILITY <mode>]                 default: SameMajorVersion (see write_basic_package_version_file)
#       [DEPENDENCIES <dep>...]                find_dependency() arguments, one string each, e.g. "Threads" "fmt 11 CONFIG"
#       [INCLUDE_DIRS <dir>...])               header trees whose contents are installed to include/
#
# Installs the targets (bin/, lib/), headers (include/) and lib/cmake/<Package>/:
#   <Package>Config.cmake, <Package>ConfigVersion.cmake, <Package>-shared|static-targets*.cmake
#
# Shared and static builds can be installed into the same prefix (give the static library a different
# OUTPUT_NAME on Windows, where it would overwrite the DLL's import .lib). Consumers choose with
#   find_package(<Package> COMPONENTS shared)   or   -D<Package>_SHARED_LIBS=ON/OFF   (strict)
#   BUILD_SHARED_LIBS of the consuming project                                       (preference)
# and otherwise get whichever is installed, shared first.
# Static libraries need their PRIVATE dependencies at link time: list them in DEPENDENCIES.

include_guard(GLOBAL)
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

function(install_package package)
    cmake_parse_arguments(PARSE_ARGV 1 ARG "" "NAMESPACE;COMPATIBILITY" "TARGETS;DEPENDENCIES;INCLUDE_DIRS")
    if(NOT ARG_TARGETS)
        message(FATAL_ERROR "install_package(${package}): TARGETS is required")
    endif()
    if(NOT DEFINED ARG_NAMESPACE)
        set(ARG_NAMESPACE "${package}::")
    endif()
    if(NOT ARG_COMPATIBILITY)
        set(ARG_COMPATIBILITY SameMajorVersion)
    endif()

    set(variant static)
    foreach(target IN LISTS ARG_TARGETS)
        get_target_property(type ${target} TYPE)
        if(type STREQUAL "SHARED_LIBRARY")
            set(variant shared)
        endif()
    endforeach()

    set(config_dir ${CMAKE_INSTALL_LIBDIR}/cmake/${package})
    install(TARGETS ${ARG_TARGETS} EXPORT ${package}-${variant}-targets
            INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
    install(EXPORT ${package}-${variant}-targets
            NAMESPACE ${ARG_NAMESPACE}
            DESTINATION ${config_dir})
    foreach(dir IN LISTS ARG_INCLUDE_DIRS)
        install(DIRECTORY ${dir}/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
    endforeach()

    set(PACKAGE ${package})
    set(DEPENDENCIES "")
    foreach(dep IN LISTS ARG_DEPENDENCIES)
        string(APPEND DEPENDENCIES "find_dependency(${dep})\n")
    endforeach()
    set(template ${CMAKE_CURRENT_BINARY_DIR}/${package}Config.cmake.in)
    file(WRITE ${template} [=[
@PACKAGE_INIT@

include(CMakeFindDependencyMacro)
@DEPENDENCIES@
# Choose the shared or static variant
set(_@PACKAGE@_want "")
if("shared" IN_LIST @PACKAGE@_FIND_COMPONENTS AND "static" IN_LIST @PACKAGE@_FIND_COMPONENTS)
    set(@PACKAGE@_FOUND FALSE)
    set(@PACKAGE@_NOT_FOUND_MESSAGE "Request either the 'shared' or the 'static' component, not both.")
    return()
elseif("shared" IN_LIST @PACKAGE@_FIND_COMPONENTS)
    set(_@PACKAGE@_want shared)
elseif("static" IN_LIST @PACKAGE@_FIND_COMPONENTS)
    set(_@PACKAGE@_want static)
elseif(DEFINED @PACKAGE@_SHARED_LIBS)
    if(@PACKAGE@_SHARED_LIBS)
        set(_@PACKAGE@_want shared)
    else()
        set(_@PACKAGE@_want static)
    endif()
endif()

set(_@PACKAGE@_file "")
if(_@PACKAGE@_want)
    set(_@PACKAGE@_file "${CMAKE_CURRENT_LIST_DIR}/@PACKAGE@-${_@PACKAGE@_want}-targets.cmake")
    if(NOT EXISTS "${_@PACKAGE@_file}")
        set(@PACKAGE@_FOUND FALSE)
        set(@PACKAGE@_NOT_FOUND_MESSAGE "The ${_@PACKAGE@_want} variant of @PACKAGE@ is not installed in ${PACKAGE_PREFIX_DIR}.")
        return()
    endif()
else()
    # BUILD_SHARED_LIBS is only a preference
    if(DEFINED BUILD_SHARED_LIBS AND NOT BUILD_SHARED_LIBS)
        set(_@PACKAGE@_order static shared)
    else()
        set(_@PACKAGE@_order shared static)
    endif()
    foreach(_@PACKAGE@_variant IN LISTS _@PACKAGE@_order)
        if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/@PACKAGE@-${_@PACKAGE@_variant}-targets.cmake")
            set(_@PACKAGE@_want ${_@PACKAGE@_variant})
            set(_@PACKAGE@_file "${CMAKE_CURRENT_LIST_DIR}/@PACKAGE@-${_@PACKAGE@_variant}-targets.cmake")
            break()
        endif()
    endforeach()
endif()

include("${_@PACKAGE@_file}")
set(@PACKAGE@_VARIANT ${_@PACKAGE@_want})
set(@PACKAGE@_${_@PACKAGE@_want}_FOUND TRUE)
check_required_components(@PACKAGE@)
]=])
    configure_package_config_file(${template} ${CMAKE_CURRENT_BINARY_DIR}/${package}Config.cmake
            INSTALL_DESTINATION ${config_dir})
    write_basic_package_version_file(${CMAKE_CURRENT_BINARY_DIR}/${package}ConfigVersion.cmake
            COMPATIBILITY ${ARG_COMPATIBILITY})
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${package}Config.cmake
                  ${CMAKE_CURRENT_BINARY_DIR}/${package}ConfigVersion.cmake
            DESTINATION ${config_dir})
endfunction()
