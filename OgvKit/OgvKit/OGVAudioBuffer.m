//
//  OGVAudioBuffer.m
//  OgvDemo
//
//  Created by Brion on 11/5/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import "OGVAudioBuffer.h"

@implementation OGVAudioBuffer

- (id)initWithPCM:(float **)pcm channels:(unsigned int)channels samples:(unsigned int)samples
{
    self = [super init];
    if (self) {
        // todo fix all this, it's broken for some reason
        NSMutableArray *dataArr = [[NSMutableArray alloc] init];
        for (unsigned int i = 0; i < channels; i++) {
            NSData *pcmData = [NSData dataWithBytes:pcm[i] length:(samples * sizeof(float))];
            [dataArr addObject:pcmData];
        }
        self.pcm = [NSArray arrayWithArray:dataArr];
        self.channels = channels;
        self.samples = samples;
    }
    return self;
}

- (const float *)pcmForChannel:(unsigned int)channel
{
    NSData *pcmData = self.pcm[channel];
    return (const float *)pcmData.bytes;
}

@end
