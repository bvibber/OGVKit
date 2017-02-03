//
//  OGVKit.m
//  OGVKit
//
//  Created by Brion on 6/28/14.
//  Copyright (c) 2014-2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

#ifdef OGVKIT_HAVE_OGG_DEMUXER
#import "OGVDecoderOgg.h"
#endif

#ifdef OGVKIT_HAVE_WEBM_DEMUXER
#import "OGVDecoderWebM.h"
#endif

#ifdef OGVKIT_HAVE_AV_DECODER
#import "OGVDecoderAV.h"
#endif

#ifdef OGVKIT_HAVE_WEBM_MUXER
#import "OGVWebMMuxer.h"
#endif

#ifdef OGVKIT_HAVE_VP8_ENCODER
#import "OGVVP8Encoder.h"
#endif

#ifdef OGVKIT_HAVE_VORBIS_ENCODER
#import "OGVVorbisEncoder.h"
#endif

@implementation OGVKit
{
    NSMutableArray *decoderClasses;
}

-(instancetype)init
{
    self = [super init];
    if (self) {
        decoderClasses = [[NSMutableArray alloc] init];

#ifdef OGVKIT_HAVE_OGG_DEMUXER
        [self registerDecoderClass:[OGVDecoderOgg class]];
#endif

#ifdef OGVKIT_HAVE_WEBM_DEMUXER
        [self registerDecoderClass:[OGVDecoderWebM class]];
#endif

#ifdef OGVKIT_HAVE_AV_DECODER
        [self registerDecoderClass:[OGVDecoderAV class]];
#endif

    }
    return self;
}

+ (OGVKit *)singleton
{
    static OGVKit *singleton;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [[OGVKit alloc] init];
    });
    return singleton;
}

- (NSBundle *)resourceBundle
{
    NSBundle *parentBundle = [NSBundle bundleForClass:[self class]];
    NSString *bundlePath = [parentBundle pathForResource:@"OGVKitResources" ofType:@"bundle"];;
    return [NSBundle bundleWithPath:bundlePath];
}


- (void)registerDecoderClass:(Class<OGVDecoder>)decoderClass
{
    @synchronized (decoderClasses) {
        [decoderClasses addObject:decoderClass];
    }
}

- (OGVDecoder *)decoderForType:(OGVMediaType *)type
{
    Class<OGVDecoder> decoderClass = [self decoderClassForType:type];
    return [[decoderClass alloc] init];
}

- (Class<OGVDecoder>)decoderClassForType:(OGVMediaType *)mediaType
{
    @synchronized (decoderClasses) {
        for (Class<OGVDecoder> decoderClass in decoderClasses) {
            if ([decoderClass canPlayType:mediaType]) {
                return decoderClass;
            }
        }
        return nil;
    }
}

- (OGVMuxer *)muxerForType:(OGVMediaType *)mediaType
{
    // hack
#ifdef OGVKIT_HAVE_WEBM_MUXER
    return [[OGVWebMMuxer alloc] init];
#else
    return nil;
#endif
}

- (OGVVideoEncoder *)videoEncoderForType:(OGVMediaType *)mediaType format:(OGVVideoFormat *)format options:(NSDictionary *)options
{
#ifdef OGVKIT_HAVE_VP8_ENCODER
    return [[OGVVP8Encoder alloc] initWithFormat:format options:options];
#else
    return nil;
#endif
}

- (OGVAudioEncoder *)audioEncoderForType:(OGVMediaType *)mediaType format:(OGVAudioFormat *)format options:(NSDictionary *)options
{
#ifdef OGVKIT_HAVE_VORBIS_ENCODER
    return [[OGVVorbisEncoder alloc] initWithFormat:format options:options];
#else
    return nil;
#endif
}

@end
