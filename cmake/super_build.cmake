# super_build.cmake - build a third-party CMake project at configure time, so find_package()
# can use it in the same configure run.
#
#   build_external_project(<name>
#       URL <url> URL_HASH SHA256=<hash>   |   GIT_REPOSITORY <url> GIT_TAG <tag>
#       [CMAKE_ARGS <-DVAR=value>...])
#
# The dependency is built with the same generator and compiler, installed into
# ${CMAKE_BINARY_DIR}/_superbuild/<name>/install, and that directory is added to CMAKE_PREFIX_PATH
# (also set as <name>_ROOT). Later configure runs skip it while the recipe is unchanged;
# delete _superbuild/<name> to force a rebuild.
#
# Multi-config generators (Visual Studio) build Debug and Release side by side ("d" postfix on Debug
# libraries), because MSVC cannot link Debug code against Release libraries.

include_guard(GLOBAL)

get_property(_ct_sb_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(_ct_sb_multi_config)
    set(_ct_sb_configs Debug Release)
    # RelWithDebInfo / MinSizeRel builds link the Release libraries
    set(CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO Release "")
    set(CMAKE_MAP_IMPORTED_CONFIG_MINSIZEREL Release "")
elseif(CMAKE_BUILD_TYPE)
    set(_ct_sb_configs ${CMAKE_BUILD_TYPE})
else()
    set(_ct_sb_configs Release)
endif()

function(build_external_project name)
    cmake_parse_arguments(PARSE_ARGV 1 ARG "" "URL;URL_HASH;GIT_REPOSITORY;GIT_TAG" "CMAKE_ARGS")
    set(dir ${CMAKE_BINARY_DIR}/_superbuild/${name})
    set(install_dir ${dir}/install)

    if(ARG_URL)
        set(source "URL [==[${ARG_URL}]==] DOWNLOAD_EXTRACT_TIMESTAMP TRUE")
        if(ARG_URL_HASH)
            string(APPEND source " URL_HASH ${ARG_URL_HASH}")
        else()
            message(WARNING "build_external_project(${name}): no URL_HASH, the download is not verified")
        endif()
    elseif(ARG_GIT_REPOSITORY)
        if(NOT ARG_GIT_TAG)
            message(FATAL_ERROR "build_external_project(${name}): GIT_TAG is required (tag, branch or commit)")
        endif()
        set(source "GIT_REPOSITORY [==[${ARG_GIT_REPOSITORY}]==] GIT_TAG ${ARG_GIT_TAG}")
        if(NOT ARG_GIT_TAG MATCHES "^[0-9a-f]{40}$") # shallow clones work for tags / branches only
            string(APPEND source " GIT_SHALLOW TRUE")
        endif()
    else()
        message(FATAL_ERROR "build_external_project(${name}): URL or GIT_REPOSITORY required")
    endif()

    # Same toolchain as this project; lists are passed with '|' (LIST_SEPARATOR below)
    set(args "-DCMAKE_INSTALL_PREFIX=${install_dir}" "-DCMAKE_POLICY_VERSION_MINIMUM=3.5")
    if(_ct_sb_multi_config)
        list(APPEND args "-DCMAKE_DEBUG_POSTFIX=d")
    else()
        list(APPEND args "-DCMAKE_BUILD_TYPE=${_ct_sb_configs}")
    endif()
    foreach(var CMAKE_C_COMPILER CMAKE_CXX_COMPILER CMAKE_TOOLCHAIN_FILE CMAKE_MSVC_RUNTIME_LIBRARY
            CMAKE_POSITION_INDEPENDENT_CODE CMAKE_PREFIX_PATH)
        if(${var})
            string(REPLACE ";" "|" value "${${var}}")
            list(APPEND args "-D${var}=${value}")
        endif()
    endforeach()
    set(cmake_args "")
    foreach(arg IN LISTS args ARG_CMAKE_ARGS)
        string(APPEND cmake_args " [==[${arg}]==]")
    endforeach()

    set(recipe "cmake_minimum_required(VERSION 3.21)
project(${name}_superbuild NONE)
include(ExternalProject)
ExternalProject_Add(${name}
    ${source}
    LIST_SEPARATOR |
    CMAKE_ARGS ${cmake_args})
")
    set(generator -G "${CMAKE_GENERATOR}")
    if(CMAKE_GENERATOR_PLATFORM)
        list(APPEND generator -A "${CMAKE_GENERATOR_PLATFORM}")
    endif()
    if(CMAKE_MAKE_PROGRAM)
        list(APPEND generator "-DCMAKE_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}")
    endif()

    string(SHA256 hash "${recipe}${generator}${_ct_sb_configs}")
    set(stamp ${install_dir}/.superbuild_stamp)
    set(old_hash "")
    if(EXISTS ${stamp})
        file(READ ${stamp} old_hash)
    endif()
    if(NOT old_hash STREQUAL hash)
        file(REMOVE ${stamp})
        file(WRITE ${dir}/CMakeLists.txt "${recipe}")
        message(STATUS "Superbuild: building ${name} (${_ct_sb_configs})")
        execute_process(COMMAND ${CMAKE_COMMAND} ${generator} -S ${dir} -B ${dir}/build
                RESULT_VARIABLE result OUTPUT_QUIET)
        foreach(config IN LISTS _ct_sb_configs)
            if(result EQUAL 0)
                execute_process(COMMAND ${CMAKE_COMMAND} --build ${dir}/build --config ${config} --parallel
                        RESULT_VARIABLE result OUTPUT_VARIABLE output ERROR_VARIABLE output)
            endif()
        endforeach()
        if(NOT result EQUAL 0)
            message(FATAL_ERROR "Superbuild: ${name} failed:\n${output}\n"
                    "Retry by hand: cmake --build ${dir}/build")
        endif()
        file(WRITE ${stamp} "${hash}")
    endif()
    message(STATUS "Superbuild: ${name} -> ${install_dir}")

    set(${name}_ROOT ${install_dir} PARENT_SCOPE)
    list(APPEND CMAKE_PREFIX_PATH ${install_dir})
    set(CMAKE_PREFIX_PATH "${CMAKE_PREFIX_PATH}" PARENT_SCOPE)
endfunction()
