.FAKE : all clean

ARCHES=i386 x86_64 armv7 armv7s arm64

all : build/Ogg.framework/Ogg build/Vorbis.framework/Vorbis build/Theora.framework/Theora

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
	./buildFramework.sh \
	  libogg \
	  Ogg \
	  "$(ARCHES)" \
	  "" \
	  "--disable-shared"

# libvorbis

build/Vorbis.framework/Vorbis : buildLib.sh buildFramework.sh build/Ogg.framework/Ogg
	./buildFramework.sh \
	  libvorbis \
	  Vorbis \
	  "$(ARCHES)" \
	  "" \
	  "--with-ogg=`pwd`/build/libogg/multiarch --disable-shared --disable-oggtest"

# libtheora
# note asm is disabled due to lack of arm64 -- fix me!
build/Theora.framework/Theora : buildLib.sh buildFramework.sh build/Ogg.framework/Ogg
	./buildFramework.sh \
	  libtheora \
	  Theora \
	  "$(ARCHES)" \
	  "" \
	  "--with-ogg=`pwd`/build/libogg/multiarch --disable-shared --disable-oggtest --disable-vorbistest --disable-examples --disable-asm"
