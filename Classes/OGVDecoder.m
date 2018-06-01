//
//  OGVDecoder.m
//  OGVKit
//
//  Created by Brion on 11/2/13.
//  Copyright (c) 2013-2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

@implementation OGVDecoder {
}

#pragma mark - stubs for subclasses to implement

- (BOOL)dequeueFrame
{
    return NO;
}

- (BOOL)dequeueAudio
{
    return NO;
}

- (BOOL)decodeFrameWithBlock:(void (^)(OGVVideoBuffer *))block
{
    return NO;
}

- (BOOL)decodeAudioWithBlock:(void (^)(OGVAudioBuffer *))block
{
    return NO;
}

- (BOOL)process
{
    return NO;
}

- (BOOL)seek:(float)seconds
{
    return NO;
}

- (float)findNextKeyframe
{
    return INFINITY;
}

#pragma mark - stub property getters

- (BOOL)seekable
{
    return NO;
}

- (float)duration
{
    return INFINITY;
}

- (BOOL)audioReady
{
    return NO;
}

- (float)audioTimestamp
{
    return -1;
}

- (BOOL)frameReady
{
    return NO;
}

- (float)frameTimestamp
{
    return -1;
}

#pragma mark - stub static methods

+ (BOOL)canPlayType:(NSString *)type
{
    return NO;
}

@end
