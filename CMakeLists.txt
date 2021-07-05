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
# cupla options
################################################################################

option(CUPLA_STREAM_ASYNC_ENABLE "Enable asynchronous streams" ON)

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
# cupla Target.
################################################################################

include("${CMAKE_CURRENT_LIST_DIR}/cmake/addExecutable.cmake")

alpaka_add_library(
    ${PROJECT_NAME}
    ${PROJECT_SOURCE_DIR}/src/manager/Driver.cpp
    ${PROJECT_SOURCE_DIR}/src/common.cpp
    ${PROJECT_SOURCE_DIR}/src/device.cpp
    ${PROJECT_SOURCE_DIR}/src/event.cpp
    ${PROJECT_SOURCE_DIR}/src/memory.cpp
    ${PROJECT_SOURCE_DIR}/src/stream.cpp
    )

target_include_directories(${PROJECT_NAME}
  PUBLIC
  $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>)

# Even if there are no sources CMAKE has to know the language.
set_target_properties(${PROJECT_NAME} PROPERTIES LINKER_LANGUAGE CXX)

target_link_libraries(
    ${PROJECT_NAME}
    PUBLIC
    alpaka::alpaka)

if(CUPLA_STREAM_ASYNC_ENABLE)
    TARGET_COMPILE_DEFINITIONS(${PROJECT_NAME} PUBLIC "CUPLA_STREAM_ASYNC_ENABLED=1")
else()
    TARGET_COMPILE_DEFINITIONS(${PROJECT_NAME} PUBLIC "CUPLA_STREAM_ASYNC_ENABLED=0")
endif()

# GNU
if(CMAKE_COMPILER_IS_GNUCXX)
  TARGET_COMPILE_OPTIONS(${PROJECT_NAME}
    PUBLIC
    "-Wall"
    "-Wextra"
    "-Wno-unknown-pragmas"
    "-Wno-unused-parameter"
    "-Wno-unused-local-typedefs"
    "-Wno-attributes"
    "-Wno-reorder"
    "-Wno-sign-compare")
# ICC
elseif(${CMAKE_CXX_COMPILER_ID} STREQUAL "Intel")
  TARGET_COMPILE_OPTIONS(${PROJECT_NAME} PUBLIC "-Wall")
# PGI
elseif(${CMAKE_CXX_COMPILER_ID} STREQUAL "PGI")
  TARGET_COMPILE_OPTIONS(${PROJECT_NAME} PUBLIC "-Minform=inform")
endif()

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
