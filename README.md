Lightweight iOS media player widget for free Ogg Theora/Vorbis and WebM VP8/VP9 codecs.

Currently provides a basic high-level player widget (OGVPlayerView) that can stream
audio and video files over HTTP(S), including seeking if Range: header is supported,
or from the local filesystem.

Will continue to improve this interface, add support for Opus audio codec, and add
lower-level interfaces suitable for transcoding to/from AVFoundation formats. See the
Roadmap section below for more detailed plans.

![Player example](https://raw.githubusercontent.com/brion/OGVKit/master/Docs/images/example.jpg)

# Status

Containers:
* Ogg
 * playback: yes
 * duration: yes (uses skeleton or slow seek)
 * seeking: yes  (uses skeleton or slow bisection)
* WebM
 * playback: yes
 * duration: yes
 * seeking: yes (requires cues)
* MP4 (backed by AVFoundation)
 * playback: yes (from URLs only)
 * duration: yes
 * seeking: yes

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

# Getting started

## Install CocoaPods

You'll need CocoaPods installed if not already for package management:

```
sudo gem install cocoapods
```

See [detailed CocoaPods setup guide](https://guides.cocoapods.org/using/getting-started.html)
if necessary.


## Building the example

First, get the source:

```
git clone https://github.com/brion/OGVKit.git
git submodule update --init
```

Set up the development pods so the example can build:

```
cd Example
pod install
```

Now open OGVKit.xcworkspace -- the workspace NOT the project! And build.

# Using OGVKit

## Adding to your project

To use the current release in your project, set up some stuff in your Podfile like so:

```
use_frameworks!

source 'https://github.com/CocoaPods/Specs.git'

# This line is needed until OGVKit is fully published to CocoaPods
# Remove once packages published:
source 'https://github.com/brion/OGVKit-Specs.git'

target 'MyXcodeProjectName' do
  pod "OGVKit"
end
```

By default, all supported file formats and codecs will be enabled. To strip out unneeded formats, use subspecs instead of specifying the default 'OGVKit':

Just WebM files, all default codec variants (VP8, Vorbis):
```
  pod "OGVKit/WebM"
```

Just Ogg files, all codec variants (Theora, Vorbis):
```
  pod "OGVKit/Ogg"
```

Just Ogg files with Vorbis audio, with no video codecs enabled:
```
  pod "OGVKit/Ogg/Vorbis"
```

It may be necessary to disable bitcode on the entire project. To ensure that generated pods projects have bitcode disabled, add to the Podfile a section:

```
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['ENABLE_BITCODE'] = 'NO'
      end
    end
  end
```


## Instantiating a player programmatically

*Warning: this API is not yet finalized.*

```
#import <OGVKit/OGVKit.h>

-(void) somethingOnYourViewController
{
    OGVPlayerView *playerView = [[OGVPlayerView alloc] initWithFrame:self.view.bounds];
    [self.view addView:playerView];
    
    playerView.delegate = self; // implement OGVPlayerDelegate protocol
    playerView.sourceURL = [NSURL URLWithString:@"http://example.com/path/to/file.webm"];
    [playerView play];
}
```

If Ogg or WebM data has been previously downloaded into an NSData memory blob, you can read this memory directly instead of reading via a file:

```
// from live HTTP(S) or file URL:
playerView.inputStream = [OGVInputStream inputStreamWithURL:@"http://example.com/path/to/file.webm"];

// from NSData
NSData *data = ...;
playerView.inputStream = [OGVInputStream inputStreamWithData:data];
```

## Instantiating a player in Interface Builder

*TODO: make easier to use in IB if possible*

* add a generic UIView to your interface
* set the custom class to OGVPlayerView
* once in the program, treat as above


## Getting updated on player state

OGVPlayerView supports a delegate protocol, OGVPlayerDelegate. *This is not a finalized API* and may change.

# Roadmap

See [milestones in issue tracker](https://github.com/brion/OGVKit/milestones) for details:

* v0.5 initial CocoaPods-compatible release
* v0.5.1 added local filesystem URL support
* v0.5.2 exposed inputStream and memory data input, fixed VP9
* v0.5.3 fixed playback after end, ogg seek fail handling
* v0.5.4 'brute force' seek for WebM audio without cues
* v0.5.5 initial MP4 support, various seek & audio fixes
* v0.5.6 end-of-file fixes with some edge cases
* v0.5.7 more seek-to-end fixes
* v0.5.8 fix regressions and old bugs in audio dropout case
* v0.5.9 fix regressions and old bugs in audio, threading

Future:
* v1 stable player API
* v1.1 extras: fullscreen, AirPlay, etc
* v1.2 performance
* v1.3 adaptive bitrate streaming
* v2 internals and API refactor
* v2.1 encoder & transcoding
