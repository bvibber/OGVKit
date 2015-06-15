Pod::Spec.new do |s|
  s.name         = "OGVKit"
  s.version      = "0.1"
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
                     :tag => "0.1",
                     :submodules => true }

  s.subspec "Player" do |skit|
    skit.requires_arc = true
    skit.source_files  = "Classes", "Classes/**/*.{h,m}"

    skit.dependency 'OGVKit/ogg'
    skit.dependency 'OGVKit/vorbis'
    skit.dependency 'OGVKit/theora'
  end

  s.subspec "ogg" do |sogg|
    sogg.compiler_flags = "-O3",
                          "-Wno-conversion"
    sogg.source_files = "libogg/src",
                        "libogg/include/**/*.h"
    sogg.public_header_files = "libogg/includes/**/*.h"
    sogg.header_dir = "ogg"
  end
  
  s.subspec "vorbis" do |svorbis|
    svorbis.compiler_flags = "-O3",
                             "-Wno-conversion",
                             "-Wno-unused-variable",
                             "-Wno-unused-function"
    svorbis.source_files = "libvorbis/lib",
                           "libvorbis/include/**/*.h"
    svorbis.exclude_files = "libvorbis/lib/psytune.c", # dead code that doesn't compile
                            "libvorbis/lib/vorbisenc.c" # don't need encoder
    svorbis.public_header_files = "libvorbis/includes/**/*.h"
    svorbis.header_dir = "vorbis"
    svorbis.dependency 'OGVKit/ogg'
  end
  
  s.subspec "theora" do |stheora|
    stheora.compiler_flags = "-O3",
                             "-Wno-conversion",
                             "-Wno-tautological-compare",
                             "-Wno-absolute-value"
    stheora.source_files = "libtheora/lib",
                           "libtheora/include/**/*.h"
    stheora.public_header_files = "libtheora/include/**/*.h"
    stheora.header_dir = "theora"
    stheora.dependency 'OGVKit/ogg'
  end

end
