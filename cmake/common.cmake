# common.cmake - project defaults and target helpers. Include after project().
#
# Defaults: Debug build type, no compiler extensions, executables + DLLs in bin/, libraries in lib/,
#           installed executables find their shared libraries in ../lib (RPATH, Linux / macOS).
#
# Options:
#   ENABLE_SANITIZERS  ASan + UBSan in Debug builds of targets passed to set_asan() (default: ON on Linux)
#   ENABLE_HARDENING   stack protector, CET, Control Flow Guard, RELRO              (default: ON)
#
# Functions:
#   set_common_flags(<target>)                              warnings + hardening
#   set_asan(<target>)                                      sanitizers, Debug only
#   set_test(<target>)                                      test framework (if found) + sanitizers + add_test()
#   copy_to_target_dir(<target> [SUBDIR <dir>] FILES <f>...) copy files next to the target's output
#   copy_runtime_dlls(<target>)                             Windows: copy DLLs of linked (imported) libraries next to the exe
#   install_deps(<exe> [DIRECTORIES <dir>...])              install <exe> and every non-system DLL / .so it needs

include_guard(GLOBAL)
if(CMAKE_VERSION VERSION_LESS 3.21)
    message(FATAL_ERROR "common.cmake needs CMake 3.21 or newer (this is ${CMAKE_VERSION})")
endif()
include(GNUInstallDirs)
include(CheckCXXCompilerFlag)

# cl.exe and clang-cl take MSVC-style options
if(MSVC OR CMAKE_CXX_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC")
    set(_ct_msvc TRUE)
else()
    set(_ct_msvc FALSE)
endif()

# MinGW has no sanitizer runtime and MSVC's needs its DLL next to the exe, so default ON only on Linux
if(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND NOT _ct_msvc)
    set(_ct_san_default ON)
else()
    set(_ct_san_default OFF)
endif()
option(ENABLE_SANITIZERS "ASan + UBSan in Debug builds of targets using set_asan()" ${_ct_san_default})
option(ENABLE_HARDENING "Stack protector / CET / Control Flow Guard / RELRO" ON)

# MSVC ASan cannot be combined with the /RTC1 checks CMake puts in the Debug flags
if(ENABLE_SANITIZERS AND _ct_msvc)
    string(REGEX REPLACE "/RTC[1csu]+" "" CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG}")
endif()

# ---------------------------------------------------------------------------------------------------------
# Defaults

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

get_property(_ct_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(NOT _ct_multi_config AND NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type" FORCE)
endif()

# DLLs must sit next to the executables on Windows, hence RUNTIME (exe + dll) -> bin/
if(NOT DEFINED CMAKE_RUNTIME_OUTPUT_DIRECTORY)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/bin)
endif()
if(NOT DEFINED CMAKE_LIBRARY_OUTPUT_DIRECTORY)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)
endif()
if(NOT DEFINED CMAKE_ARCHIVE_OUTPUT_DIRECTORY)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)
endif()

# Relocatable install: <prefix>/bin/app loads <prefix>/lib/*.so without LD_LIBRARY_PATH
if(NOT WIN32 AND NOT DEFINED CMAKE_INSTALL_RPATH)
    if(APPLE)
        set(_ct_origin "@loader_path")
    else()
        set(_ct_origin "$ORIGIN")
    endif()
    file(RELATIVE_PATH _ct_bin_to_lib "${CMAKE_INSTALL_FULL_BINDIR}" "${CMAKE_INSTALL_FULL_LIBDIR}")
    set(CMAKE_INSTALL_RPATH "${_ct_origin}/${_ct_bin_to_lib}")
endif()

# ---------------------------------------------------------------------------------------------------------

function(set_common_flags target)
    get_target_property(type ${target} TYPE)
    if(_ct_msvc)
        target_compile_options(${target} PRIVATE
                /W4 /permissive- /utf-8 /Zc:__cplusplus
                /we4715 /we4716) # missing return value -> error
        if(ENABLE_HARDENING)
            target_compile_options(${target} PRIVATE /guard:cf)
            if(NOT type STREQUAL "STATIC_LIBRARY")
                target_link_options(${target} PRIVATE /GUARD:CF)
            endif()
        endif()
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        target_compile_options(${target} PRIVATE
                -Wall -Wextra -Wpedantic -Wshadow -Wformat=2 -Wcast-qual -Wpointer-arith
                -Wundef -Wvla -Wwrite-strings -Wmissing-declarations -Werror=return-type)
        if(ENABLE_HARDENING)
            target_compile_options(${target} PRIVATE -fstack-protector-strong)
            if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
                check_cxx_compiler_flag(-fstack-clash-protection _ct_has_clash_protection)
                check_cxx_compiler_flag(-fcf-protection=full _ct_has_cf_protection) # x86 only
                target_compile_options(${target} PRIVATE
                        $<$<BOOL:${_ct_has_clash_protection}>:-fstack-clash-protection>
                        $<$<BOOL:${_ct_has_cf_protection}>:-fcf-protection=full>)
                if(NOT type STREQUAL "STATIC_LIBRARY")
                    target_link_options(${target} PRIVATE -Wl,-z,relro,-z,now)
                endif()
            endif()
        endif()
    endif()
    if(WIN32)
        target_compile_definitions(${target} PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
    endif()
endfunction()

# Link options are PUBLIC: whatever links a sanitized library needs the sanitizer runtime too.
function(set_asan target)
    if(NOT ENABLE_SANITIZERS)
        return()
    endif()
    set(debug "$<CONFIG:Debug>")
    if(_ct_msvc)
        target_compile_options(${target} PRIVATE "$<${debug}:/fsanitize=address>")
        # Allows linking non-ASan libraries (prebuilt / superbuilt) that use std::string / std::vector
        target_compile_definitions(${target} PRIVATE
                "$<${debug}:_DISABLE_STRING_ANNOTATION>" "$<${debug}:_DISABLE_VECTOR_ANNOTATION>")
        set_property(TARGET ${target} PROPERTY MSVC_RUNTIME_CHECKS "") # /RTC with CMake >= 4.0
        target_link_options(${target} PUBLIC "$<${debug}:/INCREMENTAL:NO>")
        # Copy the ASan runtime DLL next to executables so they run outside a VS developer prompt
        get_target_property(type ${target} TYPE)
        get_filename_component(compiler_dir "${CMAKE_CXX_COMPILER}" DIRECTORY)
        file(GLOB asan_dlls "${compiler_dir}/clang_rt.asan_dynamic-*.dll")
        if(type STREQUAL "EXECUTABLE" AND asan_dlls)
            add_custom_command(TARGET ${target} POST_BUILD
                    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${asan_dlls} $<TARGET_FILE_DIR:${target}>)
        endif()
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang" AND NOT MINGW)
        target_compile_options(${target} PRIVATE
                "$<${debug}:-fsanitize=address,undefined>" "$<${debug}:-fno-omit-frame-pointer>")
        target_link_options(${target} PUBLIC "$<${debug}:-fsanitize=address,undefined>")
    else()
        message(WARNING "set_asan(${target}): no sanitizers for ${CMAKE_CXX_COMPILER_ID} on ${CMAKE_SYSTEM_NAME}")
    endif()
endfunction()

function(set_test target)
    foreach(framework GTest::gtest_main Catch2::Catch2WithMain doctest::doctest_with_main)
        if(TARGET ${framework})
            target_link_libraries(${target} PRIVATE ${framework})
            break()
        endif()
    endforeach()
    set_asan(${target})
    add_test(NAME ${target} COMMAND ${target})
endfunction()

# Runs after each build of <target>, so it follows multi-config layouts (bin/Debug, bin/Release).
function(copy_to_target_dir target)
    cmake_parse_arguments(PARSE_ARGV 1 ARG "" "SUBDIR" "FILES")
    if(NOT ARG_FILES)
        return()
    endif()
    set(dest "$<TARGET_FILE_DIR:${target}>/${ARG_SUBDIR}")
    add_custom_command(TARGET ${target} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E make_directory "${dest}"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different ${ARG_FILES} "${dest}"
            VERBATIM)
endfunction()

# Lets executables linking DLLs from other packages (find_package) run and be tested from the build tree.
function(copy_runtime_dlls target)
    if(WIN32)
        set(dlls "$<TARGET_RUNTIME_DLLS:${target}>")
        add_custom_command(TARGET ${target} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E $<IF:$<BOOL:${dlls}>,copy_if_different,true> ${dlls} $<TARGET_FILE_DIR:${target}>
                COMMAND_EXPAND_LISTS)
    endif()
endfunction()

# DLLs go to bin/ (next to the exe), .so files to lib/ (found through the RPATH above).
# OS libraries and the MSVC runtime are skipped; use include(InstallRequiredSystemLibraries) to ship it.
function(install_deps target)
    cmake_parse_arguments(PARSE_ARGV 1 ARG "" "" "DIRECTORIES")
    set(dirs ${ARG_DIRECTORIES})
    foreach(prefix IN LISTS CMAKE_PREFIX_PATH)
        list(APPEND dirs ${prefix}/bin ${prefix}/lib)
    endforeach()
    if(MINGW) # libstdc++-6.dll, libgcc_s_seh-1.dll, libwinpthread-1.dll
        get_filename_component(compiler_dir "${CMAKE_CXX_COMPILER}" DIRECTORY)
        list(APPEND dirs ${compiler_dir})
    endif()
    install(TARGETS ${target}
            RUNTIME_DEPENDENCIES
            DIRECTORIES ${dirs}
            PRE_EXCLUDE_REGEXES "^api-ms-" "^ext-ms-"
            POST_EXCLUDE_REGEXES "[Ww][Ii][Nn][Dd][Oo][Ww][Ss][/\\\\][Ss][Yy][Ss]" "^/lib" "^/usr/lib")
endfunction()
