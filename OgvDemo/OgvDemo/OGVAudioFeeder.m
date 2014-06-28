//
//  OGVAudioFeeder.m
//  OgvDemo
//
//  Created by Brion on 6/28/14.
//  Copyright (c) 2014 Brion Vibber. All rights reserved.
//

#import "OGVAudioFeeder.h"

#import <AudioToolbox/AudioToolbox.h>


@interface OGVAudioFeeder()
-(void)handleQueue:(AudioQueueRef)queue buffer:(AudioQueueBufferRef)buffer;
@end

static const int nBuffers = 3;

static void OGVAudioFeederBufferHandler(void *data, AudioQueueRef queue, AudioQueueBufferRef buffer)
{
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
    AudioStreamPacketDescription packetDesc;
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
        formatDescription.mFormatFlags = kAudioFormatFlagsNativeFloatPacked |
                                         kAudioFormatFlagIsNonInterleaved;
        formatDescription.mBytesPerPacket = sizeof(Float32);
        formatDescription.mFramesPerPacket = 1;
        formatDescription.mBytesPerFrame = sizeof(Float32);
        formatDescription.mChannelsPerFrame = channels;
        formatDescription.mBitsPerChannel = sizeof(Float32) * 8;
        formatDescription.mReserved = 0;
        
        OSStatus status;
        status = AudioQueueNewOutput(&formatDescription,
                                     OGVAudioFeederBufferHandler,
                                     (__bridge void *)self,
                                     CFRunLoopGetCurrent(),
                                     kCFRunLoopCommonModes,
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
        
        AudioQueueSetParameter(queue,
                               kAudioQueueParam_Volume,
                               1.0f);
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
    [inputBuffers addObject:buffer];
    if (!isRunning && [inputBuffers count] >= nBuffers) {
        [self startAudio];
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

    if ([inputBuffers count] > 0) {
        OGVAudioBuffer *inputBuffer = inputBuffers[0];
        [inputBuffers removeObjectAtIndex:0];
        
        for (int channel = 0; channel < _channels; channel++) {

            int channelSize = inputBuffer.samples * sizeof(Float32);

            Float32 *dest = (Float32 *)buffer->mAudioData;
            NSData *source = (NSData *)inputBuffer.pcm[channel];

            memcpy(&dest[channel * channelSize],
                   [source bytes],
                   channelSize);
        }
        
        packetDesc.mVariableFramesInPacket = inputBuffer.samples;
        packetDesc.mStartOffset = 0;
        packetDesc.mDataByteSize = inputBuffer.samples * _channels * sizeof(Float32);
        AudioQueueEnqueueBuffer(queue, buffer, 1, &packetDesc);
    } else {
        NSLog(@"starved for audio?");
    }
    
    if (closing) {
        AudioQueueStop(queue, NO);
    }
}

-(void)startAudio
{
    assert(!isRunning);
    assert([inputBuffers count] >= nBuffers);
    
    // Prime the buffers!
    for (int i = 0; i < nBuffers; i++) {
        [self handleQueue:queue buffer:buffers[i]];
    }

    AudioQueueStart(queue, NULL);
    isRunning = YES;
}

@end
