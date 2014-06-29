//
//  OGVAudioFeeder.m
//  OgvDemo
//
//  Created by Brion on 6/28/14.
//  Copyright (c) 2014 Brion Vibber. All rights reserved.
//

#import "OGVAudioFeeder.h"

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface OGVAudioFeeder()
-(void)handleQueue:(AudioQueueRef)queue buffer:(AudioQueueBufferRef)buffer;
@end

static const int nBuffers = 3;

static void OGVAudioFeederBufferHandler(void *data, AudioQueueRef queue, AudioQueueBufferRef buffer)
{
    NSLog(@"bufferHandler");
    OGVAudioFeeder *feeder = (__bridge OGVAudioFeeder *)data;
    [feeder handleQueue:queue buffer:buffer];
}

@implementation OGVAudioFeeder {

    NSMutableArray *inputBuffers;
    
    AudioStreamBasicDescription formatDescription;
    AudioQueueRef queue;
    AudioQueueBufferRef buffers[nBuffers];
    
    UInt32 bufferSize;
    UInt32 bufferByteSize;
    SInt64 mCurrentPacket;
    UInt32 mNumPacketsToRead;
    BOOL isRunning;
    BOOL closing;
}

-(id)initWithSampleRate:(int)sampleRate channels:(int)channels
{
    self = [self init];
    if (self) {
        _sampleRate = sampleRate;
        _channels = channels;
        isRunning = NO;
        closing = NO;
        
        inputBuffers = [[NSMutableArray alloc] init];
        
        bufferSize = 8192;
        bufferByteSize = bufferSize * sizeof(Float32) * channels;
        
        formatDescription.mSampleRate = (Float32)sampleRate;
        formatDescription.mFormatID = kAudioFormatLinearPCM;
        formatDescription.mFormatFlags = kAudioFormatFlagsNativeFloatPacked;
        formatDescription.mBytesPerPacket = sizeof(Float32) * channels;
        formatDescription.mFramesPerPacket = 1;
        formatDescription.mBytesPerFrame = sizeof(Float32) * channels;
        formatDescription.mChannelsPerFrame = channels;
        formatDescription.mBitsPerChannel = sizeof(Float32) * 8;
        formatDescription.mReserved = 0;
        
        OSStatus status;
        status = AudioQueueNewOutput(&formatDescription,
                                     OGVAudioFeederBufferHandler,
                                     (__bridge void *)self,
                                     NULL,
                                     NULL,
                                     0,
                                     &queue);
        if (status) {
            @throw [NSException
                    exceptionWithName:@"OGVAudioFeederQueueNotCreated"
                    reason:[NSString stringWithFormat:@"err %d", status]
                    userInfo:@{}];
        }
        
        for (int i = 0; i < nBuffers; i++) {
            status = AudioQueueAllocateBuffer(queue,
                                              bufferByteSize,
                                              &buffers[i]);
            if (status) {
                @throw [NSException
                        exceptionWithName:@"OGVAudioFeederBufferNotCreated"
                        reason:[NSString stringWithFormat:@"err %d", status]
                        userInfo:@{}];
            }
        }
    }
    return self;
}

-(void)dealloc
{
    if (queue) {
        AudioQueueDispose(queue, true);
    }
}

-(void)bufferData:(OGVAudioBuffer *)buffer
{
    NSLog(@"bufferData");
    
    if (buffer.samples > 0) {
        [inputBuffers addObject:buffer];
        if (!isRunning && [inputBuffers count] >= nBuffers * 2) {
            NSLog(@"Starting audio!");
            [self startAudio];
        }
    }
}

-(void)close
{
    closing = YES;
}

-(int)samplesQueued
{
    // @todo
    return 0;
}

-(float)secondsQueued
{
    return (float)[self samplesQueued] / (float)self.sampleRate;
}

-(float)playbackPosition
{
    // @todo
    return 0.0f;
}

#pragma mark - Private methods

-(void)handleQueue:(AudioQueueRef)_queue buffer:(AudioQueueBufferRef)buffer
{
    assert(_queue != NULL);
    assert(buffer != NULL);
    assert(queue == _queue);
    
    NSLog(@"handleQueue...");

    if (closing) {
        NSLog(@"Stopping queue");
        AudioQueueStop(queue, NO);
    } else if ([inputBuffers count] > 0) {
        NSLog(@"handleQueue has data");
        OGVAudioBuffer *inputBuffer = inputBuffers[0];
        [inputBuffers removeObjectAtIndex:0];
        
        int channelSize = inputBuffer.samples * sizeof(Float32);
        int packetSize = channelSize * _channels;
        NSLog(@"channelSize %d | packetSize %d | samples %d",
              channelSize, packetSize, inputBuffer.samples);
        
        int sampleCount = inputBuffer.samples;
        
        for (int channel = 0; channel < _channels; channel++) {
            
            Float32 *dest = (Float32 *)buffer->mAudioData;
            const Float32 *source = [inputBuffer PCMForChannel:channel];
            
            for (int i = 0; i < sampleCount; i++) {
                int j = i * _channels + channel;
                dest[j] = source[i];
            }
        }
        
        buffer->mAudioDataByteSize = packetSize;

        OSStatus status;
        status = AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
        if (status) {
            @throw [NSException
                    exceptionWithName:@"OGVAudioFeederBufferNotEnqueued"
                    reason:[NSString stringWithFormat:@"err %d", status]
                    userInfo:@{}];
        }
    } else {
        NSLog(@"starved for audio?");
        /*
        buffer->mAudioDataByteSize = bufferByteSize;
        memset(buffer->mAudioData, 0, bufferByteSize);
         */
    }
}

-(void)startAudio
{
    assert(!isRunning);
    assert([inputBuffers count] >= nBuffers);
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    // Prime the buffers!
    for (int i = 0; i < nBuffers; i++) {
        [self handleQueue:queue buffer:buffers[i]];
    }
    OSStatus status;
    
    status = AudioQueueStart(queue, NULL);
    if (status) {
        @throw [NSException
                exceptionWithName:@"OGVAudioFeederQueueNotStarted"
                reason:[NSString stringWithFormat:@"err %d", status]
                userInfo:@{}];
    }
    
    isRunning = YES;
    NSLog(@"Started audio: %d", status);
}

@end
