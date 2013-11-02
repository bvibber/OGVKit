#!/bin/bash

TARGET="$1"
if [ "x$TARGET" == "x" ]; then
	echo "Pass a library subdirectory and an arch to build..."
	exit 1
fi

ARCH="$2"
if [ "x$ARCH" == "x" ]; then
	echo "Pass an arch such as i386 or armv7 to build..."
	exit 1
fi

# Adapted from http://iosdeveloperzone.com/2012/09/29/tutorial-open-source-on-ios-part-2-compiling-libogg-on-ios/

case $ARCH in
  i386 | x86_64 )
    PLATFORM=iPhoneSimulator
    platform=iphonesimulator
    HOST=$ARCH-apple-darwin
    ;;
  armv7 | armv7s | arm64 )
    PLATFORM=iPhoneOS
    platform=iphoneos
    HOST=arm-apple-darwin
    ;;
  * )
    echo "Unrecognized architecture $ARCH"
    exit 1
    ;;
esac

SDK_VERSION=7.0
SDK_MINVER=6.0

XCODE_ROOT=`xcode-select -print-path`
PLATFORM_PATH="$XCODE_ROOT/Platforms/$PLATFORM.platform/Developer"
SDK_PATH="$PLATFORM_PATH/SDKs/$PLATFORM$SDK_VERSION.sdk"
FLAGS="-isysroot $SDK_PATH -arch $ARCH -miphoneos-version-min=$SDK_MINVER"

# note: this "gcc" is actually clang
CC=`xcrun -find -sdk $platform clang`
CXX=`xcrun -find -sdk $platform g++`
CFLAGS="$FLAGS"
CXXFLAGS="$FLAGS"
LDFLAGS="$FLAGS"
export CC CXX CFLAGS CXXFLAGS LDFLAGS

OUTDIR=`pwd`"/build/$TARGET/$ARCH"
mkdir -p $OUTDIR

# configure $TARGET
cd $TARGET

# generate configuration script
./autogen.sh --host=$HOST --prefix="$OUTDIR" --disable-shared
echo ./configure --host=$HOST --prefix="$OUTDIR" --disable-shared
./configure --host=$HOST --prefix="$OUTDIR" --disable-shared || exit 1

# compile $TARGET
make clean && make && make install

cd ..
