#!/bin/bash

BUILD_DIR="boot/espressif/build"
SOURCE_DIR="boot/espressif"

. $IDF_PATH/export.sh

# ninja -C $BUILD_DIR clean
rm -r $BUILD_DIR

cmake -DCMAKE_TOOLCHAIN_FILE=tools/toolchain-esp32s3.cmake -DMCUBOOT_TARGET=esp32s3 -DESP_HAL_PATH=$IDF_PATH -S $SOURCE_DIR -B $BUILD_DIR -GNinja

ninja -C $BUILD_DIR
