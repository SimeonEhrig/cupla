#!/bin/bash

CUPLA_ROOT=$(pwd)
mkdir build
cd build
cmake ..
cmake --build .
cmake --install .
cd ${CUPLA_ROOT}
