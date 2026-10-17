# Calc: a library installed as a CMake package (see ../demo_consumer for the find_package side).
#
#   cmake -P cmake/build.cmake -- -S demo_lib -B demo_lib/build-shared --prefix <prefix>
#   cmake -P cmake/build.cmake -- -S demo_lib -B demo_lib/build-static --prefix <prefix> -DBUILD_SHARED_LIBS=OFF
#
# Both variants (and Debug / Release, Debug has a "d" postfix) can share one <prefix>.
cmake_minimum_required(VERSION 3.21...4.1)
project(Calc VERSION 1.2.0 DESCRIPTION "Demo library exported as a CMake package" LANGUAGES CXX)

option(BUILD_SHARED_LIBS "Build Calc as a shared library" ON)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../cmake)
include(common)
include(export_package)
include(GenerateExportHeader)

find_package(Threads REQUIRED)

add_library(calc src/calc.cpp)
add_library(Calc::calc ALIAS calc) # same name as the installed target, also works with add_subdirectory()
target_compile_features(calc PUBLIC cxx_std_17)
target_include_directories(calc PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
target_link_libraries(calc PRIVATE Threads::Threads)
target_compile_definitions(calc PRIVATE CALC_VERSION="${PROJECT_VERSION}")

# calc_export.h: CALC_EXPORT = dllexport / dllimport / visibility("default"), empty for static builds
generate_export_header(calc EXPORT_FILE_NAME ${CMAKE_CURRENT_BINARY_DIR}/include/calc/calc_export.h)
set_target_properties(calc PROPERTIES
        VERSION ${PROJECT_VERSION}
        SOVERSION ${PROJECT_VERSION_MAJOR}
        DEBUG_POSTFIX d
        CXX_VISIBILITY_PRESET hidden
        VISIBILITY_INLINES_HIDDEN ON)
if(NOT BUILD_SHARED_LIBS)
    target_compile_definitions(calc PUBLIC CALC_STATIC_DEFINE)
    if(WIN32) # calc.lib is already the DLL's import library
        set_target_properties(calc PROPERTIES OUTPUT_NAME calc_static)
    endif()
endif()
set_common_flags(calc)

include(CTest)
if(BUILD_TESTING)
    add_executable(test_calc tests/test_calc.cpp)
    target_link_libraries(test_calc PRIVATE calc)
    set_test(test_calc)
endif()

# Static Calc links Threads privately, so consumers need it too -> DEPENDENCIES
install_package(Calc
        TARGETS calc
        DEPENDENCIES Threads
        INCLUDE_DIRS include ${CMAKE_CURRENT_BINARY_DIR}/include)
