# Uses the installed Calc package from ../demo_lib through find_package().
#
# Tell CMake where Calc is installed, with any one of (searched in this order):
#   -DCalc_DIR=<prefix>/lib/cmake/Calc     exact directory containing CalcConfig.cmake
#   -DCalc_ROOT=<prefix>                   Calc's install prefix; only used for Calc (and its dependencies)
#                                          Also as environment variable Calc_ROOT / CALC_ROOT.
#   -DCMAKE_PREFIX_PATH=<prefix1>;<prefix2> prefixes searched for every package
#   nothing                                ../out/calc-<windows|linux>, then ../out/calc
#
#   cmake -P cmake/build.cmake -- -S demo_consumer -B demo_consumer/build -DCalc_ROOT=out/calc
#   ... -DCALC_VARIANT=static              pick a variant when both are installed
cmake_minimum_required(VERSION 3.21...4.1)
project(calc_consumer LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../cmake)
include(common)

# find_package caches Calc_DIR, so a Calc_ROOT changed on a later configure would be ignored
if(DEFINED _calc_root_used AND NOT "${Calc_ROOT}" STREQUAL "${_calc_root_used}")
    unset(Calc_DIR CACHE)
endif()
set(_calc_root_used "${Calc_ROOT}" CACHE INTERNAL "")

set(CALC_VARIANT "" CACHE STRING "Calc variant: shared, static, or empty for whichever is installed")
if(CALC_VARIANT)
    set(calc_components COMPONENTS ${CALC_VARIANT})
endif()
string(TOLOWER "${CMAKE_SYSTEM_NAME}" system)
find_package(Calc 1.0 REQUIRED ${calc_components}
        PATHS # fallback, searched after Calc_DIR / Calc_ROOT / CMAKE_PREFIX_PATH
            ${CMAKE_CURRENT_SOURCE_DIR}/../out/calc-${system}
            ${CMAKE_CURRENT_SOURCE_DIR}/../out/calc)
message(STATUS "Using Calc ${Calc_VERSION} (${Calc_VARIANT}) from ${Calc_DIR}")

add_executable(calc_app main.cpp)
target_link_libraries(calc_app PRIVATE Calc::calc)
set_common_flags(calc_app)
copy_runtime_dlls(calc_app) # Windows: calc.dll next to calc_app.exe

enable_testing()
add_test(NAME calc_app COMMAND calc_app)

install_deps(calc_app) # installs calc_app plus calc.dll / libcalc.so
