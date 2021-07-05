#
# Copyright 2016 Rene Widera, Benjamin Worpitz, Simeon Ehrig
#
# This file is part of cupla.
#
# cupla is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# cupla is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with cupla.
# If not, see <http://www.gnu.org/licenses/>.
#

################################################################################
# Required cmake version.
################################################################################

cmake_minimum_required(VERSION 3.18.0)

################################################################################
# Setup project information
################################################################################

# Find cupla version.
file(STRINGS "${CMAKE_CURRENT_LIST_DIR}/include/cupla/version.hpp" CUPLA_VERSION_MAJOR_HPP REGEX "#define CUPLA_VERSION_MAJOR ")
file(STRINGS "${CMAKE_CURRENT_LIST_DIR}/include/cupla/version.hpp" CUPLA_VERSION_MINOR_HPP REGEX "#define CUPLA_VERSION_MINOR ")
file(STRINGS "${CMAKE_CURRENT_LIST_DIR}/include/cupla/version.hpp" CUPLA_VERSION_PATCH_HPP REGEX "#define CUPLA_VERSION_PATCH ")

string(REGEX MATCH "([0-9]+)" CUPLA_VERSION_MAJOR  ${CUPLA_VERSION_MAJOR_HPP})
string(REGEX MATCH "([0-9]+)" CUPLA_VERSION_MINOR  ${CUPLA_VERSION_MINOR_HPP})
string(REGEX MATCH "([0-9]+)" CUPLA_VERSION_PATCH  ${CUPLA_VERSION_PATCH_HPP})

set(PACKAGE_VERSION "${CUPLA_VERSION_MAJOR}.${CUPLA_VERSION_MINOR}.${CUPLA_VERSION_PATCH}")


project(cupla VERSION      ${CUPLA_VERSION_MAJOR}.${CUPLA_VERSION_MINOR}.${CUPLA_VERSION_PATCH}
              DESCRIPTION  "cupla is a simple CUDA like user interface for the platform independent parallel kernel acceleration library alpaka."
              HOMEPAGE_URL "https://github.com/alpaka-group/cupla"
              LANGUAGES    CXX)
include(GNUInstallDirs)

################################################################################
# setup alpaka
################################################################################

set(cupla_ALPAKA_PROVIDER "intern" CACHE STRING "Select which alpaka is used")
set_property(CACHE cupla_ALPAKA_PROVIDER PROPERTY STRINGS "intern;extern")
mark_as_advanced(cupla_ALPAKA_PROVIDER)

if(${cupla_ALPAKA_PROVIDER} STREQUAL "intern")
    set(alpaka_BUILD_EXAMPLES OFF)
    set(BUILD_TESTING OFF)
    add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/alpaka)
else()
    set(_cupla_MIN_ALPAKA_VERSION 0.6.0)
    set(_cupla_UNSUPPORTED_ALPAKA_VERSION 0.7.0)
    find_package(alpaka REQUIRED ${_cupla_MIN_ALPAKA_VERSION} HINTS $ENV{ALPAKA_ROOT})

    if(alpaka_VERSION VERSION_GREATER_EQUAL _cupla_UNSUPPORTED_ALPAKA_VERSION)
        message(WARNING "Unsupported alpaka version ${alpaka_VERSION}. "
                "Supported versions [${_cupla_MIN_ALPAKA_VERSION},${_cupla_UNSUPPORTED_ALPAKA_VERSION}).")
    endif()
endif()

if(NOT TARGET alpaka::alpaka)
    message(ERROR "Required cupla dependency alpaka could not be found!")
endif()

################################################################################
# Directory of this file.
################################################################################
set(_cupla_ROOT_DIR ${CMAKE_CURRENT_LIST_DIR})

# Normalize the path (e.g. remove ../)
get_filename_component(_cupla_ROOT_DIR "${_cupla_ROOT_DIR}" ABSOLUTE)

# Add cupla_ADD_EXECUTABLE function.
set(_cupla_ADD_EXECUTABLE_FILE "${_cupla_ROOT_DIR}/cmake/addExecutable.cmake")
include("${_cupla_ADD_EXECUTABLE_FILE}")


################################################################################
# Compiler settings.
################################################################################
if(MSVC)
    # Empty append to define it if it does not already exist.
    list(APPEND _cupla_COMPILE_OPTIONS_PUBLIC)
else()
    # GNU
    if(CMAKE_COMPILER_IS_GNUCXX)
        list(APPEND _cupla_COMPILE_OPTIONS_PUBLIC "-Wall")
        list(APPEND _cupla_COMPILE_OPTIONS_PUBLIC "-Wextra")
        list(APPEND _cupla_COMPILE_OPTIONS_PUBLIC "-Wno-unknown-pragmas")
        list(APPEND _cupla_COMPILE_OPTIONS_PUBLIC "-Wno-unused-parameter")
        list(APPEND _cupla_COMPILE_OPTIONS_PUBLIC "-Wno-unused-local-typedefs")
        list(APPEND _cupla_COMPILE_OPTIONS_PUBLIC "-Wno-attributes")
        list(APPEND _cupla_COMPILE_OPTIONS_PUBLIC "-Wno-reorder")
        list(APPEND _cupla_COMPILE_OPTIONS_PUBLIC "-Wno-sign-compare")
    # ICC
    elseif(${CMAKE_CXX_COMPILER_ID} STREQUAL "Intel")
        list(APPEND _cupla_COMPILE_OPTIONS_PUBLIC "-Wall")
    # PGI
    elseif(${CMAKE_CXX_COMPILER_ID} STREQUAL "PGI")
        list(APPEND _cupla_COMPILE_OPTIONS_PUBLIC "-Minform=inform")
    endif()
endif()

################################################################################
# cupla.
################################################################################

option(CUPLA_STREAM_ASYNC_ENABLE "Enable asynchronous streams" ON)
if(CUPLA_STREAM_ASYNC_ENABLE)
    list(APPEND _cupla_COMPILE_DEFINITIONS_PUBLIC "CUPLA_STREAM_ASYNC_ENABLED=1")
else()
    list(APPEND _cupla_COMPILE_DEFINITIONS_PUBLIC "CUPLA_STREAM_ASYNC_ENABLED=0")
endif()

set(_cupla_INCLUDE_DIR "${_cupla_ROOT_DIR}/include")
list(APPEND _cupla_INCLUDE_DIRECTORIES_PUBLIC ${_cupla_INCLUDE_DIR})
set(_cupla_SUFFIXED_INCLUDE_DIR "${_cupla_INCLUDE_DIR}")

set(_cupla_SOURCE_DIR "${_cupla_ROOT_DIR}/src")
list(APPEND _cupla_SOURCE_DIRECTORIES_PUBLIC ${_cupla_SOURCE_DIR})
set(_cupla_SUFFIXED_SOURCE_DIR "${_cupla_SOURCE_DIR}")

set(_cupla_LINK_LIBRARY)
list(APPEND _cupla_LINK_LIBRARIES_PUBLIC ${_cupla_LINK_LIBRARY})

set(_cupla_FILES_OTHER "${_cupla_ROOT_DIR}/Findcupla.cmake" "${_cupla_ROOT_DIR}/cuplaConfig.cmake")

# Add all the include files in all recursive subdirectories and group them accordingly.
append_recursive_files_add_to_src_group("${_cupla_SUFFIXED_INCLUDE_DIR}" "${_cupla_SUFFIXED_INCLUDE_DIR}" "hpp" _cupla_FILES_HEADER)
append_recursive_files_add_to_src_group("${_cupla_SUFFIXED_INCLUDE_DIR}" "${_cupla_SUFFIXED_INCLUDE_DIR}" "h" _cupla_FILES_HEADER)

append_recursive_files_add_to_src_group("${_cupla_SUFFIXED_SOURCE_DIR}" "${_cupla_SUFFIXED_SOURCE_DIR}" "cpp" _cupla_FILES_SOURCE)


################################################################################
# cupla Target.
################################################################################

alpaka_add_library(
    "cupla"
    ${_cupla_FILES_HEADER} ${_cupla_FILES_OTHER} ${_cupla_FILES_SOURCE})

# Even if there are no sources CMAKE has to know the language.
set_target_properties("cupla" PROPERTIES LINKER_LANGUAGE CXX)

# Compile options.
message(STATUS "_cupla_COMPILE_OPTIONS_PUBLIC: ${_cupla_COMPILE_OPTIONS_PUBLIC}")
list(
    LENGTH
    _cupla_COMPILE_OPTIONS_PUBLIC
    _cupla_COMPILE_OPTIONS_PUBLIC_LENGTH)
if("${_cupla_COMPILE_OPTIONS_PUBLIC_LENGTH}")
    TARGET_COMPILE_OPTIONS(
        "cupla"
        PUBLIC ${_cupla_COMPILE_OPTIONS_PUBLIC})
endif()

# Compile definitions.
message(STATUS "_cupla_COMPILE_DEFINITIONS_PUBLIC: ${_cupla_COMPILE_DEFINITIONS_PUBLIC}")
list(
    LENGTH
    _cupla_COMPILE_DEFINITIONS_PUBLIC
    _cupla_COMPILE_DEFINITIONS_PUBLIC_LENGTH)
if("${_cupla_COMPILE_DEFINITIONS_PUBLIC_LENGTH}")
    TARGET_COMPILE_DEFINITIONS(
        "cupla"
        PUBLIC ${_cupla_COMPILE_DEFINITIONS_PUBLIC})
endif()

# Include directories.
message(STATUS "_cupla_INCLUDE_DIRECTORIES_PUBLIC: ${_cupla_INCLUDE_DIRECTORIES_PUBLIC}")
list(
    LENGTH
    _cupla_INCLUDE_DIRECTORIES_PUBLIC
    _cupla_INCLUDE_DIRECTORIES_PUBLIC_LENGTH)
if("${_cupla_INCLUDE_DIRECTORIES_PUBLIC_LENGTH}")
    TARGET_INCLUDE_DIRECTORIES(
        "cupla"
        PUBLIC ${_cupla_INCLUDE_DIRECTORIES_PUBLIC})
endif()

# Link libraries.
message(STATUS "_cupla_LINK_LIBRARIES_PUBLIC: ${_cupla_LINK_LIBRARIES_PUBLIC}")

target_link_libraries(
    "cupla"
    PUBLIC alpaka::alpaka ${_cupla_LINK_LIBRARIES_PUBLIC})


################################################################################
# add examples
################################################################################

#option(cupla_BUILD_EXAMPLES "Build examples" OFF)

#if(cupla_BUILD_EXAMPLES)
  #add_subdirectory(example/)
#endif()

################################################################################
# cuplaConfig.cmake, cuplaConfigVersion.cmake and cuplaTargest.cmake
################################################################################

include(CMakePackageConfigHelpers)

write_basic_package_version_file("${PROJECT_NAME}ConfigVersion.cmake"
                                 VERSION ${PROJECT_VERSION}
                                 COMPATIBILITY SameMajorVersion)

configure_package_config_file(
  "${PROJECT_SOURCE_DIR}/cmake/${PROJECT_NAME}Config.cmake.in"
  "${PROJECT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
  INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/cupla)
