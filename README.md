Lightweight iOS media player widget for free Ogg Theora/Vorbis and WebM VP8/VP9 codecs.

Currently provides a very primitive high-level player widget (OGVPlayerView).

Will continue to improve this interface, add support for Opus audio codec, and add
lower-level interfaces suitable for transcoding to/from AVFoundation formats. See the
Roadmap section below for more detailed plans.

# Status

Containers:
* Ogg
 * playback: yes
 * duration: not yet
 * seeking: not yet
* WebM
 * playback: yes
 * duration: not yet
 * seeking: not yet

Video:
* Theora (ogg only)
 * decode: yes
 * encode: not yet
* VP8 (WebM only)
 * decode: yes
 * encode: not yet

Audio:
* Vorbis
 * decode: yes
 * encode: not yet
* Opus
 * decode: not yet
 * encode: not yet


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

* v0.4 seeking
* v0.5 initial CocoaPods release
* v1 stable player API
* v1.1 extras: fullscreen, AirPlay, etc
* v1.2 performance
* v2 internals and API refactor
* v3 encoder & transcoding
