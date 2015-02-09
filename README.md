libogg, libvorbis, libtheora built into a wrapper library for iOS.

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

# Todo

* replace custom buffer types with CMSampleBuffers for better interop?
* better decoder class
* add an encoder class!
* Opus support
* improve the demo app
