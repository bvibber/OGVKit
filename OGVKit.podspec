Pod::Spec.new do |s|
  s.name         = "OGVKit"
  s.version      = "0.3"
  s.summary      = "Ogg Vorbis/Theora and WebM media playback widget for iOS."

  s.description  = <<-DESC
                   Ogg Vorbis/Theora and WebM media playback widget for iOS.
                   Packages Xiph.org's libogg, libvorbis, and libtheora, and
                   uses Google's VPX library, along with a UIView subclass
                   to play a video or audio file from a URL.
                   DESC

  s.homepage     = "https://github.com/brion/OGVKit"

  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author             = { "Brion Vibber" => "brion@pobox.com" }
  s.social_media_url   = "https://brionv.com/"

  s.platform     = :ios, "6.0"

  s.source       = { :git => "https://github.com/brion/OGVKit.git",
                     :tag => "0.3" }

  s.source_files = "Classes/OGVKit.{h,m}",
                   "Classes/OGVAudioFormat.{h,m}",
                   "Classes/OGVAudioBuffer.{h,m}",
                   "Classes/OGVVideoFormat.{h,m}",
                   "Classes/OGVFrameBuffer.{h,m}",
                   "Classes/OGVStreamFile.{h,m}",
                   "Classes/OGVDecoder.{h,m}",
                   "Classes/OGVFrameView.{h,m}",
                   "Classes/OGVAudioFeeder.{h,m}",
                   "Classes/OGVPlayerState.{h,m}",
                   "Classes/OGVPlayerView.{h,m}"

  s.public_header_files = "Classes/OGVKit.h",
                          "Classes/OGVAudioFormat.h",
                          "Classes/OGVAudioBuffer.h",
                          "Classes/OGVVideoFormat.h",
                          "Classes/OGVFrameBuffer.h",
                          "Classes/OGVStreamFile.h",
                          "Classes/OGVDecoder.h",
                          "Classes/OGVFrameView.h",
                          "Classes/OGVAudioFeeder.h",
                          "Classes/OGVPlayerState.h",
                          "Classes/OGVPlayerView.h"

  s.header_dir = 'OGVKit'

  s.resource_bundle = {
    'OGVKitResources' => [
      'Resources/OGVFrameView.fsh',
      'Resources/OGVFrameView.vsh',
      'Resources/OGVPlayerView.xib',
      'Resources/ogvkit-iconfont.ttf'
    ]
  }

  s.subspec "Ogg" do |subspec|
    subspec.subspec "Decoder" do |subsubspec|
      subsubspec.dependency 'OGVKit/Ogg/Demuxer'
      subsubspec.dependency 'OGVKit/Ogg/Theora/Decoder'
      subsubspec.dependency 'OGVKit/Ogg/Vorbis/Decoder'
    end

    subspec.subspec "Demuxer" do |subsubspec|
      subsubspec.xcconfig = { 'OTHER_CFLAGS' => '-DOGVKIT_HAVE_OGG_DEMUXER' }
      subsubspec.source_files = "Classes/OGVDecoderOgg.{h,m}"
      subsubspec.dependency 'libogg'
    end

    subspec.subspec "Theora" do |subsubspec|
      subsubspec.subspec "Decoder" do |subsubsubspec|
        subsubsubspec.xcconfig = { 'OTHER_CFLAGS' => '-DOGVKIT_HAVE_OGG_THEORA_DECODER' }
        subsubsubspec.dependency 'OGVKit/Ogg/Demuxer'
        subsubsubspec.dependency 'OGVKit/Ogg/Vorbis/Decoder'
        subsubsubspec.dependency 'libtheora'
      end
    end

    subspec.subspec "Vorbis" do |subsubspec|
      subsubspec.subspec "Decoder" do |subsubsubspec|
        subsubsubspec.xcconfig = { 'OTHER_CFLAGS' => '-DOGVKIT_HAVE_OGG_VORBIS_DECODER' }
        subsubsubspec.dependency 'OGVKit/Ogg/Demuxer'
        subsubsubspec.dependency 'libvorbis'
      end
    end
  end

  s.subspec "WebM" do |subspec|
    subspec.subspec "Decoder" do |subsubspec|
      subsubspec.dependency 'OGVKit/WebM/Demuxer'
      subsubspec.dependency 'OGVKit/WebM/VP8/Decoder'
    end

    subspec.subspec "Demuxer" do |subsubspec|
      subsubspec.xcconfig = { 'OTHER_CFLAGS' => '-DOGVKIT_HAVE_WEBM_DEMUXER' }
      subsubspec.source_files = "Classes/OGVDecoderWebM.{h,m}"
      subsubspec.public_header_files = "Classes/OGVDecoderWebM.h"

      subsubspec.dependency 'libnestegg'
    end

    subspec.subspec "VP8" do |subsubspec|
      subsubspec.subspec "Decoder" do |subsubsubspec|
        subsubsubspec.xcconfig = { 'OTHER_CFLAGS' => '-DOGVKIT_HAVE_WEBM_VP8_DECODER' }
        subsubsubspec.dependency 'OGVKit/WebM/Demuxer'
        subsubsubspec.dependency 'OGVKit/WebM/Vorbis/Decoder'
        subsubsubspec.dependency 'libvpx', '~>1.4.0-snapshot-20150619'
      end
    end

    subspec.subspec "Vorbis" do |subsubspec|
      subsubspec.subspec "Decoder" do |subsubsubspec|
        subsubsubspec.xcconfig = { 'OTHER_CFLAGS' => '-DOGVKIT_HAVE_WEBM_VORBIS_DECODER' }
        subsubsubspec.dependency 'OGVKit/WebM/Demuxer'
        subsubsubspec.dependency 'libvorbis'
      end
    end
  end
end
