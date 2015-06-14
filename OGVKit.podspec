Pod::Spec.new do |s|
  s.name         = "OGVKit"
  s.version      = "0.0.1"
  s.summary      = "Ogg Vorbis/Theora media playback widget for iOS."

  s.description  = <<-DESC
                   Ogg Vorbis/Theora media playback widget for iOS. Packages Xiph.org's
                   libogg, libvorbis, and libtheora along with a UIView subclass
                   to play a video or audio file from a URL.
                   DESC

  s.homepage     = "https://github.com/brion/OGVKit"

  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author             = { "Brion Vibber" => "brion@pobox.com" }
  s.social_media_url   = "https://brionv.com/"

  s.platform     = :ios, "6.0"

  s.source       = { :git => "https://github.com/brion/OGVKit.git",
                     :tag => "0.0.1",
                     :submodules => true }

  s.prepare_command = <<-CMD
    # Fill out this handy assembler file with neon options
    cat ./libtheora/lib/arm/armopts.s.in \
      | sed 's/@HAVE_ARM_ASM_EDSP@/0/' \
      | sed 's/@HAVE_ARM_ASM_MEDIA@/0/' \
      | sed 's/@HAVE_ARM_ASM_NEON@/1/' \
      > ./libtheora/lib/arm/armopts.s

    # Convert assembly for Theora to work with Apple compiler
    for filename in ./libtheora/lib/arm/*.s; do
      gnu_S="${filename%.s}-gnu.S"
      apple_S="${filename%.s}-apple.S"
      ./libtheora/lib/arm/arm2gnu.pl < "$filename" > "$gnu_S"
      GASPP_DEBUG=1 \
        ./gas-preprocessor/gas-preprocessor.pl \
          -arch arm \
          -as-type apple-clang \
          -- \
          clang \
          "$gnu_S" \
          < "$gnu_S" \
          | sed 's/-gnu.S/-apple.S/' \
          > "$apple_S"
    done
  CMD

  s.subspec "Player" do |skit|
    skit.requires_arc = true
    skit.source_files  = "Classes", "Classes/**/*.{h,m}"

    skit.dependency 'OGVKit/ogg'
    skit.dependency 'OGVKit/vorbis'
    skit.dependency 'OGVKit/theora'
  end

  s.subspec "ogg" do |sogg|
    sogg.ios.deployment_target = "6.0"
    sogg.source_files = "libogg/src",
                        "libogg/include/**/*.h"
    sogg.public_header_files = "libogg/includes/**/*.h"
    sogg.header_dir = "ogg"
  end
  
  s.subspec "vorbis" do |svorbis|
    svorbis.ios.deployment_target = "6.0"
    svorbis.source_files = "libvorbis/lib",
                           "libvorbis/include/**/*.h"
    svorbis.exclude_files = "libvorbis/lib/psytune.c", # dead code that doesn't compile
                            "libvorbis/lib/vorbisenc.c" # don't need encoder
    svorbis.public_header_files = "libvorbis/includes/**/*.h"
    svorbis.header_dir = "vorbis"
    svorbis.dependency 'OGVKit/ogg'
  end
  
  s.subspec "theora" do |stheora|
    stheora.compiler_flags = "-DOC_ARM_ASM", "-DOC_ARM_ASM_NEON"
    stheora.ios.deployment_target = "6.0"
    stheora.source_files = "libtheora/lib",
                           "libtheora/lib/arm/*{.c,.h,-apple.S}",
                           "libtheora/include/**/*.h"
    stheora.public_header_files = "libtheora/include/**/*.h"
    stheora.header_dir = "theora"
    stheora.dependency 'OGVKit/ogg'
  end

end
