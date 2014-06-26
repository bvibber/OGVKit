OUTDIR=`pwd`"/build/out"
ARCHDIR=`pwd`"/build/arch"

mkdir -p $OUTDIR

pushd $ARCHDIR
	ARCHES=`echo *`
popd

pushd $ARCHDIR/i386/lib
	LIBS=`echo *.a`
popd

echo Copying stub i386 files to multiarch out...
rsync -av $ARCHDIR/i386/ $OUTDIR/

echo $ARCHES
echo $LIBS

echo "Building fat binaries..."
for LIB in $LIBS; do
	LIPO="lipo -create -output $OUTDIR/lib/$LIB"
	for ARCH in $ARCHES; do
		LIPO="$LIPO -arch $ARCH $ARCHDIR/$ARCH/lib/$LIB"
	done
	echo $LIPO
	$LIPO
done
