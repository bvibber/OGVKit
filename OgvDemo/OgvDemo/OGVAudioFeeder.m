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
    AudioQueueBufferRef queueBuffer;
    BOOL audioStarted;
}

static void audioCallbackProxy(void                 *inUserData,
                          AudioQueueRef        inAQ,
                          AudioQueueBufferRef  inBuffer)
{
    NSLog(@"audio callback!");
    OGVAudioFeeder *feeder = (__bridge OGVAudioFeeder *)inUserData;
    [feeder onAudioCallback:inBuffer];
}

- (void)onAudioCallback:(AudioQueueBufferRef)buffer
{
    OGVAudioBuffer *audioBuffer = [self popBuffer];
    if (audioBuffer) {
        [self enqueueBuffer:audioBuffer queueBuffer:buffer];
    } else {
        NSLog(@"Starved for audio!");
    }
}

- (id)initWithChannels:(int)channels sampleRate:(int)rate
{
    OSStatus status;
    self = [super init];
    if (self) {
        buffers = [[NSMutableArray alloc] init];

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
                                     NULL,
                                     NULL,
                                     0,
                                     &queue);
        if (status) {
            NSString *err = [NSString stringWithFormat:@"Error %d from AudioQueueNewOutput", status];
            @throw [NSException exceptionWithName:@"OGVAudioFeederException" reason:err userInfo:nil];
        }

        status = AudioQueueAllocateBuffer(queue, 16384 /*?*/, &queueBuffer);
        if (status) {
            NSString *err = [NSString stringWithFormat:@"Error %d from AudioQueueAllocateBuffer", status];
            @throw [NSException exceptionWithName:@"OGVAudioFeederException" reason:err userInfo:nil];
        }
    }
    return self;
}

- (void)dealloc
{
    if (audioStarted) {
        AudioQueueStop(queue, true);
    }
    AudioQueueFreeBuffer(queue, queueBuffer);
    AudioQueueDispose(queue, true);
}

- (BOOL)buffersAvailable
{
    @synchronized (buffers) {
        return [buffers count] > 0;
    }
}

- (OGVAudioBuffer *)popBuffer
{
    @synchronized (buffers) {
        if ([self buffersAvailable]) {
            OGVAudioBuffer *buffer = buffers[0];
            [buffers removeObjectAtIndex:0];
            return buffer;
        } else {
            return nil;
        }
    }
}

- (void)pushBuffer:(OGVAudioBuffer *)buffer
{
    @synchronized (buffers) {
        if (audioStarted) {
            [buffers addObject:buffer];
        } else {
            [self enqueueBuffer:buffer queueBuffer:queueBuffer];
            [self startAudio];
        }
    }
}

- (void)startAudio
{
    OSStatus status;
    
    status = AudioQueueStart(queue, NULL);
    if (status) {
        NSString *err = [NSString stringWithFormat:@"Error %d from AudioQueueStart", status];
        @throw [NSException exceptionWithName:@"OGVAudioFeederException" reason:err userInfo:nil];
    }
    
    audioStarted = YES;
    NSLog(@"We have audio start!");
}

- (void)enqueueBuffer:(OGVAudioBuffer *)audioBuffer queueBuffer:(AudioQueueBufferRef)buffer
{
    OSStatus status;
    int channels = format.mChannelsPerFrame;
    int bytesPerChannel = audioBuffer.samples * sizeof(float);
    int bytesPerPacket = bytesPerChannel * channels;
    float *dst = buffer->mAudioData;
    
    buffer->mAudioDataByteSize = bytesPerPacket;
    for (int channel = 0; channel < channels; channel++) {
        NSData *channelData = audioBuffer.pcm[channel];
        memcpy(dst + (channel * bytesPerChannel), channelData.bytes, bytesPerChannel);
    }
    
    AudioStreamPacketDescription packetDescs;
    packetDescs.mStartOffset = 0;
    packetDescs.mDataByteSize = bytesPerChannel * channels;
    packetDescs.mVariableFramesInPacket = audioBuffer.samples;
    
    status = AudioQueueEnqueueBuffer(queue, buffer, 1, &packetDescs);
    if (status) {
        NSString *err = [NSString stringWithFormat:@"Error %d from AudioQueueEnqueueBuffer", status];
        @throw [NSException exceptionWithName:@"OGVAudioFeederException" reason:err userInfo:nil];
    }
}

@end
