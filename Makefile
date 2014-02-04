.FAKE : all clean

ARCHES=i386 x86_64 armv7 armv7s arm64

all : ogg.framework vorbis.framework theora.framework

clean:
	rm -rf build
	test -f libogg/Makefile && (cd libogg && make distclean) || true
	rm -f libogg/configure
	test -f libvorbis/Makefile && (cd libvorbis && make distclean) || true
	rm -f libvorbis/configure
	test -f libtheora/Makefile && (cd libtheora && make distclean) || true
	rm -f libtheora/configure


# libogg

ogg.framework : buildLib.sh buildFramework.sh
	./buildFramework.sh \
	  libogg \
	  ogg \
	  "$(ARCHES)" \
	  "" \
	  "--disable-shared"

# libvorbis

vorbis.framework : buildLib.sh buildFramework.sh ogg.framework
	./buildFramework.sh \
	  libvorbis \
	  vorbis \
	  "$(ARCHES)" \
	  "" \
	  "--with-ogg=`pwd`/build/libogg/multiarch --disable-shared --disable-oggtest"

# libtheora
# note asm is disabled due to lack of arm64 -- fix me!
theora.framework : buildLib.sh buildFramework.sh ogg.framework
	./buildFramework.sh \
	  libtheora \
	  theora \
	  "$(ARCHES)" \
	  "" \
	  "--with-ogg=`pwd`/build/libogg/multiarch --disable-shared --disable-oggtest --disable-vorbistest --disable-examples --disable-asm"
