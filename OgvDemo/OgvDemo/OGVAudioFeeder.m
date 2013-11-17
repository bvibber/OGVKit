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
    OGVAudioBuffer *lastBuffer;
    AudioStreamBasicDescription format;
    AudioQueueRef queue;
    AudioQueueBufferRef queueBuffer;
    BOOL audioStarted;
    BOOL audioQueued;
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
    OGVAudioBuffer *audioBuffer = [self popBuffer];
    if (audioBuffer) {
        [self enqueueBuffer:audioBuffer queueBuffer:buffer];
        audioQueued = YES;
    } else {
        NSLog(@"Starved for audio! Requeuing same buffer!");
        [self enqueueBuffer:lastBuffer queueBuffer:buffer];
        audioQueued = YES;
    }
}

- (id)initWithChannels:(int)channels sampleRate:(int)rate
{
    OSStatus status;
    self = [super init];
    if (self) {
        buffers = [[NSMutableArray alloc] init];

        NSLog(@"Setting up channels:%d rate:%d", channels, rate);
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
            NSString *err = [NSString stringWithFormat:@"Error %d from AudioQueueNewOutput", (int)status];
            @throw [NSException exceptionWithName:@"OGVAudioFeederException" reason:err userInfo:nil];
        }

        status = AudioQueueAllocateBufferWithPacketDescriptions(queue, 65536 /*?*/, 1, &queueBuffer);
        if (status) {
            NSString *err = [NSString stringWithFormat:@"Error %d from AudioQueueAllocateBufferWithPacketDescriptions", (int)status];
            @throw [NSException exceptionWithName:@"OGVAudioFeederException" reason:err userInfo:nil];
        }

        //[self startAudio];
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
            NSLog(@"popping -- got one");
            return buffer;
        } else {
            NSLog(@"popping -- nothing");
            return nil;
        }
    }
}

- (void)pushBuffer:(OGVAudioBuffer *)buffer
{
    @synchronized (buffers) {
        if (audioQueued) {
            NSLog(@"pushing buffer");
            [buffers addObject:buffer];
        } else {
            NSLog(@"queueing buffer");
            [self enqueueBuffer:buffer queueBuffer:queueBuffer];
        }
        if (!audioStarted) {
            [self startAudio];
        }
    }
}

- (void)startAudio
{
    OSStatus status;
    
    status = AudioQueuePrime(queue, 0, NULL);
    if (status) {
        NSString *err = [NSString stringWithFormat:@"Error %d from AudioQueuePrime", (int)status];
        @throw [NSException exceptionWithName:@"OGVAudioFeederException" reason:err userInfo:nil];
    }

    status = AudioQueueSetParameter(queue, kAudioQueueParam_Volume, 1.0f);
    if (status) {
        NSString *err = [NSString stringWithFormat:@"Error %d from AudioQueueSetParameter", (int)status];
        @throw [NSException exceptionWithName:@"OGVAudioFeederException" reason:err userInfo:nil];
    }

    status = AudioQueueStart(queue, NULL);
    if (status) {
        NSString *err = [NSString stringWithFormat:@"Error %d from AudioQueueStart", (int)status];
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
    
    buffer->mPacketDescriptionCount = 1;
    buffer->mPacketDescriptions[0].mStartOffset = 0;
    buffer->mPacketDescriptions[0].mDataByteSize = bytesPerChannel * channels;
    buffer->mPacketDescriptions[0].mVariableFramesInPacket = audioBuffer.samples;
    NSLog(@"Packet data size %d, frames %d", buffer->mPacketDescriptions[0].mDataByteSize, buffer->mPacketDescriptions[0].mVariableFramesInPacket);
    
    status = AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
    if (status) {
        NSString *err = [NSString stringWithFormat:@"Error %d from AudioQueueEnqueueBuffer", (int)status];
        @throw [NSException exceptionWithName:@"OGVAudioFeederException" reason:err userInfo:nil];
    }

    audioQueued = YES;
    lastBuffer = audioBuffer;
}

@end
