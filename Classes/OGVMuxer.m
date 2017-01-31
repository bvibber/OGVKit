//
//  OGVMuxer.m
//  OGVKit
//
//  Copyright (c) 2016 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

@implementation OGVMuxer

-(void)addAudioTrackFormat:(OGVAudioFormat *)audioFormat
{
    _audioFormat = audioFormat;
}

-(void)addVideoTrackFormat:(OGVVideoFormat *)videoFormat
{
    _videoFormat = videoFormat;
}

-(void)openOutputStream:(OGVOutputStream *)outputStream
{
    _outputStream = outputStream;
}

-(void)appendAudioPacket:(OGVPacket *)packet
{
    NSLog(@"encoding not implemented");
}

-(void)appendVideoPacket:(OGVPacket *)packet
{
    NSLog(@"encoding not implemented");
}

-(void)close
{
    // no-op
}

@end
