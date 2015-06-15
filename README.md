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

See [milestones in issue tracker](https://github.com/brion/OGVKit/milestones) for details:

* v0 development
 * v0.1 basics
 * v0.2 controls
 * v0.3 i/o refactor & seeking
 * v0.4 formats: WebM, Opus
 * v0.5 initial CocoaPods release
* v1 stable player API
 * v1.1 extras: fullscreen, AirPlay, etc
 * v1.2 performance
* v2 internals and API refactor
* v3 encoder & transcoding
