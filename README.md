libogg, libvorbis, libtheora built into a wrapper library for iOS.

Highly experimental!

Based on older build instructions found at http://iosdeveloperzone.com/2012/09/30/tutorial-open-source-on-ios-part-4-compiling-libvorbis/

# Prerequisites

* Mac OS X 10.9 machine
* Xcode 5.1 with iOS 7.1 SDK and CLI tools installed
* install autoconf, automake, and libtool from Homebrew
* (...hopefully that's it...)

# Building dependencies

First, get the source:

```
git clone https://github.com/brion/OgvKit.git
git submodule update --init
```

Now build the various low-level libraries!

```
make
```

There are two directories with Xcode projects:

* OgvKit -- static Cocoa Touch library that wraps the decoders with an Obj-C interface
* OgvDemo -- sample application using OgvKit to play videos from Wikimedia Commons (currently without audio)


# Todo

* replace custom buffer types with CMSampleBuffers for better interop?
* drop-in video player class
* better decoder class
* add an encoder class!
* Opus support
* improve the demo app
