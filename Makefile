.FAKE : all clean

ARCHES=i386 x86_64 armv7 armv7s arm64

all : build/ogg.framework/ogg build/vorbis.framework/vorbis build/theora.framework/theora

clean:
	rm -rf build
	test -f libogg/Makefile && (cd libogg && make distclean) || true
	rm -f libogg/configure
	test -f libvorbis/Makefile && (cd libvorbis && make distclean) || true
	rm -f libvorbis/configure
	test -f libtheora/Makefile && (cd libtheora && make distclean) || true
	rm -f libtheora/configure


# libogg

build/ogg.framework/ogg : buildLib.sh buildFramework.sh
	./buildFramework.sh \
	  libogg \
	  ogg \
	  "$(ARCHES)" \
	  "" \
	  "--disable-shared"

# libvorbis

build/vorbis.framework/vorbis : buildLib.sh buildFramework.sh build/ogg.framework/ogg
	./buildFramework.sh \
	  libvorbis \
	  vorbis \
	  "$(ARCHES)" \
	  "" \
	  "--with-ogg=`pwd`/build/libogg/multiarch --disable-shared --disable-oggtest"

# libtheora
# note asm is disabled due to lack of arm64 -- fix me!
build/theora.framework/theora : buildLib.sh buildFramework.sh build/ogg.framework/ogg
	./buildFramework.sh \
	  libtheora \
	  theora \
	  "$(ARCHES)" \
	  "" \
	  "--with-ogg=`pwd`/build/libogg/multiarch --disable-shared --disable-oggtest --disable-vorbistest --disable-examples --disable-asm"
