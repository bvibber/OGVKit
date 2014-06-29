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

CONFIGOPT="$3"

# Adapted from http://iosdeveloperzone.com/2012/09/29/tutorial-open-source-on-ios-part-2-compiling-libogg-on-ios/

case $ARCH in
  i386 | x86_64 )
    PLATFORM=iPhoneSimulator
    platform=iphonesimulator
    # darwin13 == iOS 6 min requirement
    HOST=$ARCH-apple-darwin13
    ;;
  armv7 | armv7s | arm64 )
    PLATFORM=iPhoneOS
    platform=iphoneos
    HOST=arm-apple-darwin13
    ;;
  * )
    echo "Unrecognized architecture $ARCH"
    exit 1
    ;;
esac

SDK_VERSION=7.1
SDK_MINVER=6.0

XCODE_ROOT=`xcode-select -print-path`
PLATFORM_PATH="$XCODE_ROOT/Platforms/$PLATFORM.platform/Developer"
SDK_PATH="$PLATFORM_PATH/SDKs/$PLATFORM$SDK_VERSION.sdk"
FLAGS="-isysroot $SDK_PATH -arch $ARCH -miphoneos-version-min=$SDK_MINVER"
FLAGS="$FLAGS -g"

CC=`xcrun -find -sdk $platform clang`
CXX=`xcrun -find -sdk $platform clang++`
CFLAGS="$FLAGS"
CXXFLAGS="$FLAGS"
LDFLAGS="$FLAGS"
export CC CXX CFLAGS CXXFLAGS LDFLAGS
echo "CC=$CC"
echo "CXX=$CXX"
echo "CFLAGS=$CFLAGS"


SRCDIR=`pwd`/$TARGET

OUTDIR=`pwd`"/build/arch/$ARCH"
mkdir -p $OUTDIR

BUILDDIR=`pwd`"/build/obj/$ARCH/$TARGET"
mkdir -p $BUILDDIR

# configure $TARGET
pushd $BUILDDIR

# generate configuration script and configure
$SRCDIR/configure --host=$HOST --prefix="$OUTDIR" $CONFIGOPT || exit 1

# compile $TARGET
make clean && make && make install || exit 1

popd
