LIB="$1"
ARCHES="$2"
CONFIGOPT="$3"

echo "Generating config for $LIB..."
pushd $LIB
	./autogen.sh --help
popd

echo "Building $LIB..."
for ARCH in $ARCHES; do
	echo "Building $LIB for $ARCH"
	./buildLibForArch.sh $LIB $ARCH "$CONFIGOPT" || exit 1
done
