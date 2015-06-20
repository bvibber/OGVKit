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

  s.source_files = "Classes/OGVKit.h",
                   "Classes/OGVAudioBuffer.{h,m}",
                   "Classes/OGVFrameBuffer.{h,m}",
                   "Classes/OGVFrameView.{h,m}",
                   "Classes/OGVAudioFeeder.{h,m}",
                   "Classes/OGVPlayerState.{h,m}",
                   "Classes/OGVPlayerView.{h,m}"

  s.public_header_files = "Classes/OGVKit.h",
                          "Classes/OGVAudioBuffer.h",
                          "Classes/OGVFrameBuffer.h",
                          "Classes/OGVFrameView.h",
                          "Classes/OGVAudioFeeder.h",
                          "Classes/OGVPlayerState.h",
                          "Classes/OGVPlayerView.h"

  s.header_dir = 'OGVKit'

  s.resource_bundle = {
    'OGVPlayerResources' => [
      'Resources/*.xib',
      'Resources/*.ttf'
    ]
  }

  s.subspec "Decoder" do |subspec|
    subspec.xcconfig = { 'OTHER_CFLAGS' => '$(inherited) -DOGVKIT_HAVE_DECODER' }

    subspec.subspec "Ogg" do |subsubspec|
      subsubspec.dependency 'OGVKit/Demuxer/Ogg'

      subsubspec.subspec "Theora" do |subsubsubspec|
        subsubsubspec.dependency 'OGVKit/Decoder/Theora'
        subsubsubspec.dependency 'OGVKit/Decoder/Vorbis'
      end

      subsubspec.subspec "Vorbis" do |subsubsubspec|
        subsubsubspec.dependency 'OGVKit/Decoder/Vorbis'
      end
    end

    subspec.subspec "WebM" do |subsubspec|
      subsubspec.dependency 'OGVKit/Demuxer/WebM'

      subsubspec.subspec "VP8" do |subsubsubspec|
        subsubsubspec.dependency 'OGVKit/Decoder/VP8'
        subsubsubspec.dependency 'OGVKit/Decoder/Vorbis'
      end

      subsubspec.subspec "Vorbis" do |subsubsubspec|
        subsubsubspec.dependency 'OGVKit/Decoder/Vorbis'
      end
    end

    subspec.subspec "Vorbis" do |subsubspec|
      subsubspec.xcconfig = { 'OTHER_CFLAGS' => '$(inherited) -DOGVKIT_HAVE_DECODER_VORBIS' }
      subsubspec.dependency 'libvorbis'
    end

    subspec.subspec "Theora" do |subsubspec|
      subsubspec.xcconfig = { 'OTHER_CFLAGS' => '$(inherited) -DOGVKIT_HAVE_DECODER_THEORA' }
      subsubspec.dependency 'libtheora'
    end

    subspec.subspec "VP8" do |subsubspec|
      subsubspec.xcconfig = { 'OTHER_CFLAGS' => '$(inherited) -DOGVKIT_HAVE_DECODER_VP8' }
      subsubspec.dependency 'libvpx', '~>1.4.0-snapshot-20150619'
    end
  end

  s.subspec "Demuxer" do |subspec|
    subspec.xcconfig = { 'OTHER_CFLAGS' => '$(inherited) -DOGVKIT_HAVE_DEMUXER' }

    # todo split demuxer from decoder
    subspec.source_files = "Classes/OGVDecoder.{h,m}",
                           "Classes/OGVStreamFile.{h,m}"
    subspec.public_header_files = "Classes/OGVDecoder.h",
                                  "Classes/OGVStreamFile.h"

    subspec.subspec "Ogg" do |subsubspec|
      subsubspec.xcconfig = { 'OTHER_CFLAGS' => '$(inherited) -DOGVKIT_HAVE_DEMUXER_OGG' }
      subsubspec.source_files = "Classes/OGVDecoderOgg.{h,m}"
      subsubspec.public_header_files = "Classes/OGVDecoderOgg.h"

      subsubspec.dependency 'libogg'
    end

    subspec.subspec "WebM" do |subsubspec|
      subsubspec.xcconfig = { 'OTHER_CFLAGS' => '$(inherited) -DOGVKIT_HAVE_DEMUXER_WEBM' }
      subsubspec.source_files = "Classes/OGVDecoderWebM.{h,m}"
      subsubspec.public_header_files = "Classes/OGVDecoderWebM.h"

      subsubspec.dependency 'libnestegg'
    end
  end

end
