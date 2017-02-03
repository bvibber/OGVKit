//
//  OGVAudioFormat.m
//  OGVKit
//
//  Created by Brion on 6/21/2015
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

@implementation OGVAudioFormat

- (instancetype)initWithChannels:(unsigned int)channels sampleRate:(float)sampleRate
{
    self = [super init];
    if (self) {
        _channels = channels;
        _sampleRate = sampleRate;
    }
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (!object) {
        return NO;
    }
    if ([object class] != [self class]) {
        return NO;
    }
    if (self == object) {
        return YES;
    }
    OGVAudioFormat *other = object;
    return (self.channels == other.channels) &&
           (self.sampleRate == other.sampleRate);
}

@end
