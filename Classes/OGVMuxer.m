//
//  OGVMuxer.m
//  OGVKit
//
//  Copyright (c) 2016 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

@implementation OGVMuxer

-(instancetype)initWithOutputStream:(NSOutputStream *)outputStream
                        audioFormat:(OGVAudioFormat *)audioFormat
                        videoFormat:(OGVVideoFormat *)videoFormat
{
    self = [self init];
    if (self) {
        self.audioFormat = audioFormat;
        self.videoFormat = videoFormat;
    }
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
