.FAKE : all clean

ARCHES=i386 x86_64 armv7 armv7s arm64

all : build/Ogg.framework/Ogg

clean:
	rm -rf build
	test -f libogg/Makefile && (cd libogg && make distclean) || true
	rm -f libogg/configure
	test -f libvorbis/Makefile && (cd libvorbis && make distclean) || true
	rm -f libvorbis/configure
	test -f libtheora/Makefile && (cd libtheora && make distclean) || true
	rm -f libtheora/configure


# libogg

build/Ogg.framework/Ogg : buildLib.sh buildFramework.sh
	./buildFramework.sh libogg Ogg "$(ARCHES)"

# libvorbis

# libtheora
