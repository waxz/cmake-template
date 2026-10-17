# Demo project for the helpers in ../cmake.
#
# Build, test and install on Windows or Linux (run from the directory above demo/):
#
#   cmake -P cmake/build.cmake -- -S demo -B demo/build [--config Debug] [--prefix demo/install] [--package] [--clean]
#
# By hand (Visual Studio is multi-config: pass --config / -C to every step after configure):
#
#   cmake -S demo -B demo/build -G "Visual Studio 18 2026" -A x64
#   cmake --build demo/build --config Release
#   ctest --test-dir demo/build -C Release
#   cmake --install demo/build --config Release --prefix demo/install
#
# -DDEMO_USE_SUPERBUILD=ON downloads and builds {fmt} at configure time.
cmake_minimum_required(VERSION 3.21...4.1)
project(cmake_tools_demo VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_POSITION_INDEPENDENT_CODE ON) # static libs linked into shared libs need -fPIC

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../cmake)
include(common)
include(super_build)
include(GenerateExportHeader)

option(DEMO_USE_SUPERBUILD "Build {fmt} at configure time and use it in the app" OFF)
if(DEMO_USE_SUPERBUILD)
    build_external_project(fmt
            URL https://github.com/fmtlib/fmt/releases/download/11.0.2/fmt-11.0.2.zip
            URL_HASH SHA256=40fc58bebcf38c759e11a7bd8fdc163507d2423ef5058bba7f26280c5b9c5465
            CMAKE_ARGS -DFMT_DOC=OFF -DFMT_TEST=OFF)
    find_package(fmt CONFIG REQUIRED)
endif()
find_package(Threads REQUIRED)

# Static library
add_library(mathutil STATIC src/mathutil.cpp)
target_include_directories(mathutil PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
set_common_flags(mathutil)
set_asan(mathutil)

# Shared library (a DLL on Windows, placed in bin/ next to the executables)
add_library(greeter SHARED src/greeter.cpp)
generate_export_header(greeter EXPORT_FILE_NAME ${CMAKE_CURRENT_BINARY_DIR}/include/greeter/greeter_export.h)
target_include_directories(greeter PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
target_link_libraries(greeter PRIVATE mathutil)
set_target_properties(greeter PROPERTIES
        VERSION ${PROJECT_VERSION}
        SOVERSION ${PROJECT_VERSION_MAJOR}
        CXX_VISIBILITY_PRESET hidden
        VISIBILITY_INLINES_HIDDEN ON)
set_common_flags(greeter)
set_asan(greeter)

# Executable
add_executable(demo_app app/main.cpp)
target_link_libraries(demo_app PRIVATE greeter mathutil Threads::Threads)
if(DEMO_USE_SUPERBUILD)
    target_link_libraries(demo_app PRIVATE fmt::fmt)
    target_compile_definitions(demo_app PRIVATE DEMO_HAS_FMT)
endif()
set_common_flags(demo_app)
set_asan(demo_app)
copy_to_target_dir(demo_app SUBDIR config FILES ${CMAKE_CURRENT_SOURCE_DIR}/config/demo.yaml)

# Tests
include(CTest)
if(BUILD_TESTING)
    add_executable(test_mathutil tests/test_mathutil.cpp)
    target_link_libraries(test_mathutil PRIVATE mathutil)
    set_test(test_mathutil)
endif()

# Install: the SDK (libraries + headers), and the app with every DLL / .so it needs
install(TARGETS greeter mathutil)
install(DIRECTORY include/ ${CMAKE_CURRENT_BINARY_DIR}/include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
install_deps(demo_app)
install(FILES config/demo.yaml DESTINATION ${CMAKE_INSTALL_BINDIR}/config)

# Packages (zip / NSIS installer on Windows, tar.gz / deb on Linux): build.cmake --package
set(CPACK_PACKAGE_CONTACT "Demo Maintainer <demo@example.com>")
include(package)
