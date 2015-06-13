Lightweight iOS media player widget for free Ogg Theora/Vorbis codecs.

Currently provides a very primitive high-level player widget (OGVPlayerView).

Will continue to improve this interface, add support for Opus audio codec,
WebM container and VP8/VP9 video, and add lower-level interfaces suitable for
transcoding to/from AVFoundation formats. See the Roadmap section below for more
detailed plans.


# Install CocoaPods

You'll need CocoaPods installed if not already for package management:

```
sudo gem install cocoapods
```

# Building the example

First, get the source:

```
git clone https://github.com/brion/OGVKit.git
git submodule update --init
```

Set up the development pods so the example refers to the build info:

```
cd Example
pod update
```

Now open OGVKit.xcworkspace -- the workspace NOT the project! And build.


# Roadmap

v0.1 basics:
* fix audio-only files
* fix video-only files

v0.2 controls:
* pause/continue buttons
* volume control

v0.3 i/o refactor:
* OGVStreamFile and sync interface on top for the demuxer to use
* buffer to temp storage instead of RAM
* progress bar / seek scrubber
* byte-range seeking
* seeking with liboggz / libskeleton

v0.4 formats:
* WebM support with nestegg/vpx

v1.0 cleanup:
* clean up API, source for usage in Wikipedia app

v1.1 extras:
* fullscreen
* HDMI/AirPlay output

v1.2 perf:
* recycle buffers
* try to get ARM assembly bits for theora & vorbis working
* try Metal for the YUV conversion?

v2.0 internals and API refactor:
* separate out libraries as their own pods?
* replace custom buffer types with CMSampleBuffers for easier interop?
* label for Swift usage?

v3.0 transcoding:
* add an encoder class!
* transcode helper class for saving to H.264/AAC or producing ogv/webm from one
