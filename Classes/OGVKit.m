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

@end
