#!/bin/bash
set -o xtrace

# Change Working Directory to build
BUILD_DIR=$(dirname "${0}")/../build
mkdir -p $BUILD_DIR
pushd $BUILD_DIR > /dev/null
WORKING_DIR=`pwd`
export OUTPUT_DIR="$WORKING_DIR/output"
mkdir -p $OUTPUT_DIR

SCRIPTS_DIR=$WORKING_DIR/../scripts
echo "WORKING_DIR : $WORKING_DIR"
echo "SCRIPTS_DIR : $SCRIPTS_DIR"
echo "OUTPUT_DIR  : $OUTPUT_DIR"
LIPO="xcrun -sdk iphoneos lipo"

# Verify Tools Are Installed
command -v cmake >/dev/null 2>&1 || { echo >&2 "cmake required but it's not installed.  Aborting."; exit 1; }

# Download the latest library
LIBRARY_TAG="v3.0.18"
LIBRARY_TARBALL="libical"
if [ ! -d  ./$LIBRARY_TARBALL ]; then
  LIBRARY_DISTRO_URL="https://github.com/libical/libical"
  git clone --branch $LIBRARY_TAG $LIBRARY_DISTRO_URL
fi

LIBRARY_DIR="libical"
pushd $LIBRARY_DIR > /dev/null

ARCH="arm64" $SCRIPTS_DIR/libical_make.sh device
ARCH="arm64" $SCRIPTS_DIR/libical_make.sh sim
ARCH="x86_64" $SCRIPTS_DIR/libical_make.sh sim
rm -rf $OUTPUT_DIR/sim-lib
rm -rf $OUTPUT_DIR/device-lib
mkdir -p $OUTPUT_DIR/sim-lib
mkdir -p $OUTPUT_DIR/device-lib
cp -f $OUTPUT_DIR/arm64_device/libical.a $OUTPUT_DIR/device-lib
$LIPO \
    -arch arm64  $OUTPUT_DIR/arm64_sim/libical.a \
    -arch x86_64 $OUTPUT_DIR/x86_64_sim/libical.a \
    -create -output $OUTPUT_DIR/sim-lib/libical.a
xcodebuild -create-xcframework \
    -library $OUTPUT_DIR/device-lib/libical.a \
    -library $OUTPUT_DIR/sim-lib/libical.a \
    -headers $OUTPUT_DIR/../../src/include \
    -output $OUTPUT_DIR/ical.xcframework

# make zoneinfo directory
pushd build/zoneinfo
make install
popd  >/dev/null

# Move things to their final place
mkdir -p ../../lib
mv -f $OUTPUT_DIR/ical.xcframework ../../lib
mkdir -p ../../src/include
cp  -f ./build/src/libical/ical.h ../../src/include
cp  -f ./build/src/libical/ical.h ../../../XbICalendar/XBICalendar/include
cp  -f ./src/libical/libical_ical_export.h ../../src/include
cp  -f ./src/libical/libical_ical_export.h ../../../XbICalendar/XBICalendar/include
rm -rf ../../zoneinfo
mv  $OUTPUT_DIR/share/libical/zoneinfo ../../zoneinfo

# Return to previous working directory
popd  > /dev/null

exit