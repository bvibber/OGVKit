LIB="$1"
NAME="$2"
ARCHES="$3"
FLAGS="$4"
CONFIGOPT="$5"

echo "Building $LIB..."
for ARCH in $ARCHES; do
	echo "Building $LIB for $ARCH"
	./buildLib.sh $LIB $ARCH "$FLAGS" "$CONFIGOPT" || exit 1
done

echo "Copying stub files from i386 for $LIB"
test -d build/$LIB/multiarch || mkdir -p build/$LIB/multiarch
rsync -av build/$LIB/i386/ build/$LIB/multiarch/ || exit 1

echo "Creating fat library for $LIB"
rm -f build/$LIB/multiarch/lib/$LIB.a
LIPO="lipo -create -output build/$LIB/multiarch/lib/$LIB.a"
for ARCH in $ARCHES; do
  LIPO="$LIPO -arch $ARCH build/$LIB/$ARCH/lib/$LIB.a"
done
echo $LIPO
`$LIPO`

echo "Building $NAME.framework"
test -d build/$NAME.framework/Headers || mkdir -p build/$NAME.framework/Headers
rsync -av build/$LIB/multiarch/include/ build/$NAME.framework/Headers/ || exit 1
cp -p build/$LIB/multiarch/lib/$LIB.a build/$NAME.framework/$NAME
