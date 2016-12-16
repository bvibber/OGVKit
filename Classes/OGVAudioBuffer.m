//
//  OGVAudioBuffer.m
//  OGVKit
//
//  Created by Brion on 11/5/13.
//  Copyright (c) 2013-2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

@implementation OGVAudioBuffer
{
    NSArray *_pcm;
}

- (id)initWithPCM:(float **)pcm samples:(unsigned int )samples format:(OGVAudioFormat *)format timestamp:(float)timestamp
{
    self = [super init];
    if (self) {
        _format = format;
        _samples = samples;
        _timestamp = timestamp;

        NSMutableArray *dataArr = [[NSMutableArray alloc] init];
        for (unsigned int i = 0; i < format.channels; i++) {
            NSData *pcmData = [NSData dataWithBytes:pcm[i] length:(samples * sizeof(float))];
            [dataArr addObject:pcmData];
        }
        _pcm = [NSArray arrayWithArray:dataArr];
    }
    return self;
}

- (const float *)PCMForChannel:(unsigned int)channel
{
    NSData *pcmData = _pcm[channel];
    return (const float *)pcmData.bytes;
}

@end
