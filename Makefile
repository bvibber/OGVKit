.FAKE : all clean

ARCHES=i386 x86_64 armv7 armv7s arm64

# common prefix for convenience
BUILD=build/arch/i386/lib
OUT=build/out/lib

all : $(OUT)/libogg.a

clean:
	rm -rf build


# libogg

$(BUILD)/libogg.a : buildLib.sh buildLibForArch.sh
	./buildLib.sh \
	  libogg \
	  "$(ARCHES)" \
	  "--disable-shared"

# libvorbis

$(BUILD)/libvorbis.a : $(BUILD)/libogg.a
	./buildLib.sh \
	  libvorbis \
	  "$(ARCHES)" \
	  "--disable-shared --disable-oggtest"

# libtheora
# note asm is disabled due to lack of arm64 -- fix me!
$(BUILD)/libtheora.a : $(BUILD)/libogg.a
	./buildLib.sh \
	  libtheora \
	  "$(ARCHES)" \
	  "--disable-shared --disable-oggtest --disable-vorbistest --disable-examples --disable-asm"

$(OUT)/libogg.a : $(BUILD)/libogg.a $(BUILD)/libvorbis.a $(BUILD)/libtheora.a buildFatLibs.sh
	./buildFatLibs.sh
