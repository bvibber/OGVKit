//
//  OGVAudioFeeder.m
//  OgvDemo
//
//  Created by Brion on 11/11/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import "OGVAudioFeeder.h"
#import <AudioToolbox/AudioToolbox.h>

@implementation OGVAudioFeeder {
    NSMutableArray *buffers;
    AudioStreamBasicDescription format;
    AudioQueueRef queue;
}

static void audioCallbackProxy(void                 *inUserData,
                          AudioQueueRef        inAQ,
                          AudioQueueBufferRef  inBuffer)
{
    OGVAudioFeeder *feeder = (__bridge OGVAudioFeeder *)inUserData;
    [feeder onAudioCallback:inBuffer];
}

- (void)onAudioCallback:(AudioQueueBufferRef)buffer
{
    OSStatus status;
    
    if ([buffers count] > 0) {
        OGVAudioBuffer *nextBuffer = buffers[0];
        [buffers removeObjectAtIndex:0];
        
        int channels = format.mChannelsPerFrame;
        int bytesPerChannel = nextBuffer.samples * sizeof(float);
        float *dst = buffer->mAudioData;
        
        buffer->mAudioDataByteSize = bytesPerChannel * channels;
        for (int channel = 0; channel < channels; channel++) {
            NSData *channelData = nextBuffer.pcm[channel];
            memcpy(dst + channel * bytesPerChannel, channelData.bytes, bytesPerChannel);
        }
        status = AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
    } else {
        NSLog(@"Starved for audio!");
    }
}

- (id)initWithChannels:(int)channels sampleRate:(int)rate
{
    OSStatus status;
    self = [super init];
    if (self) {
        format.mSampleRate = rate;
        format.mFormatID = kAudioFormatLinearPCM;
        format.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved;
        format.mBytesPerPacket = 0; // variable
        format.mFramesPerPacket = 0; // variable
        format.mChannelsPerFrame = channels;
        format.mBitsPerChannel = 8 * sizeof (float);
        format.mReserved = 0;
        status = AudioQueueNewOutput(&format,
                                     audioCallbackProxy,
                                     (__bridge void *)self,
                                     (__bridge CFRunLoopRef)[NSRunLoop mainRunLoop],
                                     NULL,
                                     0,
                                     &queue);
    }
    return self;
}

- (void)dealloc
{
    AudioQueueDispose(queue, true);
}

@end
