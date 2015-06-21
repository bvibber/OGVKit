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

To use the current release *WHICH DOES NOT YET EXIST* in your project, set up some stuff in your Podfile like so:

```
source 'https://github.com/CocoaPods/Specs.git'

# This line is needed until OGVKit is fully published to CocoaPods
# Remove once packages published:
source 'https://github.com/brion/OGVKit-Specs.git'

target 'MyXcodeProjectName' do
  pod "OGVKit"
end

# hack for missing resource bundle on iPad builds
# https://github.com/CocoaPods/CocoaPods/issues/2292
# Remove once bug fixed is better:
post_install do |installer|
  installer.project.targets.each do |target|
    if target.product_reference.name == 'OGVKitResources.bundle' then
      target.build_configurations.each do |config|
        config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2' # iPhone, iPad
      end
    end
  end
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

## Instantiating a player in Interface Builder

*TODO: make easier to use in IB if possible*

* add a generic UIView to your interface
* set the custom class to OGVPlayerView
* once in the program, treat as above


## Getting updated on player state

OGVPlayerView supports a delegate protocol, OGVPlayerDelegate. *This is not a finalized API* and may change.

# Roadmap

See [milestones in issue tracker](https://github.com/brion/OGVKit/milestones) for details:

* v0.4 seeking
* v0.5 initial CocoaPods release
* v1 stable player API
* v1.1 extras: fullscreen, AirPlay, etc
* v1.2 performance
* v2 internals and API refactor
* v3 encoder & transcoding
