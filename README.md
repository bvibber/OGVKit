libogg, libvorbis, libtheora built into a wrapper library for iOS.

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


# Todo

* replace custom buffer types with CMSampleBuffers for better interop?
* better decoder class
* add an encoder class!
* Opus support
* improve the demo app
