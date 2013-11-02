LIB="$1"
NAME="$2"
ARCHES="$3"

echo "Building $LIB..."
for ARCH in $ARCHES; do
	echo "Building $LIB for $ARCH"
	./buildLib.sh libogg $ARCH
done

echo "Copying headers for $LIB"
test -d build/$NAME.framework/Headers || mkdir -p build/$NAME.framework/Headers
rsync -av build/i386/include/ build/$NAME.framework/Headers/

LIPO="lipo -create -output build/$NAME.framework/$NAME"
for ARCH in $ARCHES; do
  LIPO="$LIPO -arch $ARCH build/$LIB/$ARCH/lib/$LIB.a"
done

echo "Creating fat library for $LIB"
echo $LIPO
`$LIPO`
