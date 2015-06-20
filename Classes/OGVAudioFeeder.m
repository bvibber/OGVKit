//
//  OGVAudioFeeder.m
//  OGVKit
//
//  Created by Brion on 6/28/14.
//  Copyright (c) 2014 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface OGVAudioFeeder(Private)

-(void)handleQueue:(AudioQueueRef)queue buffer:(AudioQueueBufferRef)buffer;
-(void)handleQueue:(AudioQueueRef)queue propChanged:(AudioQueuePropertyID)prop;

-(int)buffersQueued;
-(void)queueInput:(OGVAudioBuffer *)buffer;
-(OGVAudioBuffer *)nextInput;

@end

static const int nBuffers = 16;

typedef OSStatus (^OSStatusWrapperBlock)();

static void throwIfError(OSStatusWrapperBlock wrappedBlock) {
    OSStatus status = wrappedBlock();
    if (status != 0) {
        @throw [NSException
                exceptionWithName:@"OGVAudioFeederAudioQueueException"
                reason:[NSString stringWithFormat:@"err %d", (int)status]
                userInfo:@{@"OSStatus": @(status)}];
    }
}

typedef void (^NSErrorWrapperBlock)(NSError **err);

static void throwIfNSError(NSErrorWrapperBlock wrappedBlock) {
    NSError *error = nil;
    wrappedBlock(&error);
    if (error) {
        @throw [NSException exceptionWithName:@"OGVAudioFeederAudioQueueException"
                                       reason:[error localizedDescription]
                                     userInfo:@{@"NSError": error}];
    }
}

static void OGVAudioFeederBufferHandler(void *data, AudioQueueRef queue, AudioQueueBufferRef buffer)
{
    //NSLog(@"bufferHandler");
    OGVAudioFeeder *feeder = (__bridge OGVAudioFeeder *)data;
    @autoreleasepool {
        [feeder handleQueue:queue buffer:buffer];
    }
}

static void OGVAudioFeederPropListener(void *data, AudioQueueRef queue, AudioQueuePropertyID prop) {
    OGVAudioFeeder *feeder = (__bridge OGVAudioFeeder *)data;
    @autoreleasepool {
        [feeder handleQueue:queue propChanged:prop];
    }
}

@implementation OGVAudioFeeder {

    NSObject *timeLock;

    NSMutableArray *inputBuffers;
    int samplesQueued;
    int samplesPlayed;
    int samplesOfSilence;
    
    AudioStreamBasicDescription formatDescription;
    AudioQueueRef queue;
    AudioQueueBufferRef buffers[nBuffers];
    
    UInt32 sampleSize;
    UInt32 bufferSize;
    UInt32 bufferByteSize;

    BOOL isStarting;
    BOOL isRunning;
    BOOL isClosing;
}

-(id)initWithSampleRate:(int)sampleRate channels:(int)channels
{
    self = [self init];
    if (self) {
        timeLock = [[NSObject alloc] init];

        _sampleRate = sampleRate;
        _channels = channels;
        isStarting = NO;
        isRunning = NO;
        isClosing = NO;
        
        inputBuffers = [[NSMutableArray alloc] init];
        samplesQueued = 0;
        samplesPlayed = 0;
        samplesOfSilence = 0;
        
        sampleSize = sizeof(Float32);
        bufferSize = 8192;
        bufferByteSize = bufferSize * sampleSize * channels;
        
        formatDescription.mSampleRate = (Float32)sampleRate;
        formatDescription.mFormatID = kAudioFormatLinearPCM;
        formatDescription.mFormatFlags = kLinearPCMFormatFlagIsFloat;
        formatDescription.mBytesPerPacket = sampleSize * channels;
        formatDescription.mFramesPerPacket = 1;
        formatDescription.mBytesPerFrame = sampleSize * channels;
        formatDescription.mChannelsPerFrame = channels;
        formatDescription.mBitsPerChannel = sampleSize * 8;
        formatDescription.mReserved = 0;
        
        throwIfError(^() {
            return AudioQueueNewOutput(&formatDescription,
                                       OGVAudioFeederBufferHandler,
                                       (__bridge void *)self,
                                       NULL,
                                       NULL,
                                       0,
                                       &queue);
        });
        
        for (int i = 0; i < nBuffers; i++) {
            throwIfError(^() {
                return AudioQueueAllocateBuffer(queue,
                                                bufferByteSize,
                                                &buffers[i]);
            });
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
    @synchronized (timeLock) {
        assert(buffer.samples <= bufferSize);
        
        //NSLog(@"queuing samples: %d", buffer.samples);
        if (buffer.samples > 0) {
            [self queueInput:buffer];
            //NSLog(@"buffer count: %d", [self buffersQueued]);
            if (!isStarting && !isRunning && [self buffersQueued] >= nBuffers) {
                //NSLog(@"Starting audio!");
                [self startAudio];
            }
        }
    }
}

-(BOOL)isStarted
{
    @synchronized (timeLock) {
        return isStarting || isRunning;
    }
}

-(void)close
{
    @synchronized (timeLock) {
        isClosing = YES;
    }
}

-(int)samplesQueued
{
    @synchronized (timeLock) {
        return samplesQueued - samplesPlayed;
    }
}

-(float)secondsQueued
{
    return (float)[self samplesQueued] / (float)self.sampleRate;
}

-(float)playbackPosition
{
    @synchronized (timeLock) {
        if (isRunning) {
            __block AudioTimeStamp ts;
            
            throwIfError(^() {
                return AudioQueueGetCurrentTime(queue, NULL, &ts, NULL);
            });

            float samplesOutput = ts.mSampleTime;
            float samplesOutputWithoutSilence = samplesOutput - samplesOfSilence;
            return samplesOutputWithoutSilence / (float)self.sampleRate;
        } else {
            return 0.0f;
        }
    }
}

-(float)bufferTailPosition
{
    @synchronized (timeLock) {
        return samplesQueued / (float)self.sampleRate;
    }
}

#pragma mark - Private methods

-(void)handleQueue:(AudioQueueRef)_queue buffer:(AudioQueueBufferRef)buffer
{
    @synchronized (timeLock) {
        if (isClosing) {
            //NSLog(@"Stopping queue");
            AudioQueueStop(queue, YES);
            return;
        }
        
        OGVAudioBuffer *inputBuffer = [self nextInput];
        
        if (inputBuffer) {
            //NSLog(@"handleQueue has data");
            
            int channelSize = inputBuffer.samples * sampleSize;
            int packetSize = channelSize * _channels;
            //NSLog(@"channelSize %d | packetSize %d | samples %d", channelSize, packetSize, inputBuffer.samples);
            
            int sampleCount = inputBuffer.samples;
            Float32 *dest = (Float32 *)buffer->mAudioData;
            
            for (int channel = 0; channel < _channels; channel++) {
                
                const Float32 *source = [inputBuffer PCMForChannel:channel];
                
                for (int i = 0; i < sampleCount; i++) {
                    int j = i * _channels + channel;
                    dest[j] = source[i];
                }
            }
            
            buffer->mAudioDataByteSize = packetSize;
        } else {
            //NSLog(@"starved for audio?");
            
            // Buy us some decode time with some blank audio
            int silence = bufferSize;
            silence = 1024; // ????
            samplesOfSilence += silence;
            buffer->mAudioDataByteSize = silence * sampleSize * self.channels;
            memset(buffer->mAudioData, 0, buffer->mAudioDataByteSize);
        }
        
        throwIfError(^() {
            return AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
        });
    }
}

-(void)handleQueue:(AudioQueueRef)_queue propChanged:(AudioQueuePropertyID)prop
{
    @synchronized (timeLock) {
        if (prop == kAudioQueueProperty_IsRunning) {
            __block UInt32 _isRunning = 0;
            __block UInt32 _size = sizeof(_isRunning);
            throwIfError(^(){
                return AudioQueueGetProperty(queue, prop, &_isRunning, &_size);
            });
            isRunning = (BOOL)_isRunning;
            //NSLog(@"isRunning is %d", (int)isRunning);
        }
    }
}

-(void)startAudio
{
    @synchronized (timeLock) {
        if (isStarting) {
            // This... probably shouldn't happen.
            return;
        }
        assert(!isRunning);
        assert([inputBuffers count] >= nBuffers);

        isStarting = YES;

        throwIfNSError(^(NSError **err) {
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:err];
        });
        
        // Prime the buffers!
        for (int i = 0; i < nBuffers; i++) {
            [self handleQueue:queue buffer:buffers[i]];
        }

        throwIfError(^(){
            // Set a listener to update isRunning
            return AudioQueueAddPropertyListener(queue,
                                                 kAudioQueueProperty_IsRunning,
                                                 OGVAudioFeederPropListener,
                                                 (__bridge void *)self);
        });

        throwIfError(^() {
            return AudioQueueStart(queue, NULL);
        });
    }
}

-(int)buffersQueued
{
    @synchronized (timeLock) {
        return (int)[inputBuffers count];
    }
}

-(void)queueInput:(OGVAudioBuffer *)buffer
{
    @synchronized (timeLock) {
        [inputBuffers addObject:buffer];
        samplesQueued += buffer.samples;
    }
}

-(OGVAudioBuffer *)nextInput
{
    @synchronized (timeLock) {
        if ([inputBuffers count] > 0) {
            OGVAudioBuffer *inputBuffer = inputBuffers[0];
            [inputBuffers removeObjectAtIndex:0];
            samplesPlayed += inputBuffer.samples;
            return inputBuffer;
        } else {
            return nil;
        }
    }
}

@end
