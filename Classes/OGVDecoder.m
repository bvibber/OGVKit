//
//  OGVDecoder.m
//  OGVKit
//
//  Created by Brion on 11/2/13.
//  Copyright (c) 2013-2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

#ifdef OGVKIT_HAVE_OGG_DEMUXER
#import "OGVDecoderOgg.h"
#endif

#ifdef OGVKIT_HAVE_WEBM_DEMUXER
#import "OGVDecoderWebM.h"
#endif

static NSMutableArray *OGVDecoderClasses;

@implementation OGVDecoder {
}

#pragma mark - stubs for subclasses to implement

- (BOOL)decodeFrame
{
    return NO;
}

- (BOOL)decodeAudio
{
    return NO;
}

- (OGVVideoBuffer *)frameBuffer
{
    return nil;
}

- (OGVAudioBuffer *)audioBuffer
{
    return nil;
}

- (BOOL)process
{
    return NO;
}

+ (BOOL)canPlayType:(NSString *)type
{
    return NO;
}

#pragma mark - global stuff

+ (void)setup
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        OGVDecoderClasses = [[NSMutableArray alloc] init];

#ifdef OGVKIT_HAVE_OGG_DEMUXER
        [OGVDecoderClasses addObject:[OGVDecoderOgg class]];
#endif

#ifdef OGVKIT_HAVE_WEBM_DEMUXER
        [OGVDecoderClasses addObject:[OGVDecoderWebM class]];
#endif
    });
}

+ (void)registerDecoderClass:(Class<OGVDecoder>)decoderClass
{
    [OGVDecoder setup];
    [OGVDecoderClasses addObject:decoderClass];
}

+ (OGVDecoder *)decoderForType:(NSString *)type
{
    Class<OGVDecoder> decoderClass = [OGVDecoder decoderClassForType:type];
    return [[decoderClass alloc] init];
}

+ (Class<OGVDecoder>)decoderClassForType:(NSString *)type
{
    [OGVDecoder setup];
    for (Class<OGVDecoder> decoderClass in OGVDecoderClasses) {
        if ([decoderClass canPlayType:type]) {
            return decoderClass;
        }
    }
    return nil;
}

@end
