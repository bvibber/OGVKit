//
//  OGVAudioFeeder.m
//  OGVKit
//
//  Created by Brion on 6/28/14.
//  Copyright (c) 2014-2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface OGVAudioFeeder(Private)

-(void)handleQueue:(AudioQueueRef)queue buffer:(AudioQueueBufferRef)buffer;
-(void)handleQueue:(AudioQueueRef)queue propChanged:(AudioQueuePropertyID)prop;

-(void)queueInput:(OGVAudioBuffer *)buffer;
-(OGVAudioBuffer *)nextInput;

@end

static const int nBuffers = 3;
static const int circularBufferSize = 8192 * 16;

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
    
    Float32 *circularBuffer;
    size_t circularHead;
    size_t circularTail;

    int samplesQueued;
    int samplesPlayed;
    
    AudioStreamBasicDescription formatDescription;
    AudioQueueRef queue;
    AudioQueueBufferRef buffers[nBuffers];
    
    UInt32 sampleSize;
    UInt32 bufferSize;
    UInt32 bufferByteSize;

    BOOL isStarting;
    BOOL isRunning;
    BOOL isClosing;
    BOOL isClosed;
    BOOL shouldClose;
}

-(id)initWithFormat:(OGVAudioFormat *)format
{
    self = [self init];
    if (self) {
        timeLock = [[NSObject alloc] init];

        _format = format;
        isStarting = NO;
        isRunning = NO;
        isClosing = NO;
        isClosed = NO;
        shouldClose = NO;

        samplesQueued = 0;
        samplesPlayed = 0;
        
        sampleSize = sizeof(Float32);
        bufferSize = 1024;
        bufferByteSize = bufferSize * sampleSize * format.channels;

        circularBuffer = (Float32 *)malloc(circularBufferSize * sampleSize * format.channels);
        circularHead = 0;
        circularTail = 0;

        formatDescription.mSampleRate = format.sampleRate;
        formatDescription.mFormatID = kAudioFormatLinearPCM;
        formatDescription.mFormatFlags = kLinearPCMFormatFlagIsFloat;
        formatDescription.mBytesPerPacket = sampleSize * format.channels;
        formatDescription.mFramesPerPacket = 1;
        formatDescription.mBytesPerFrame = sampleSize * format.channels;
        formatDescription.mChannelsPerFrame = format.channels;
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
    if (circularBuffer) {
        free(circularBuffer);
    }
}

-(void)bufferData:(OGVAudioBuffer *)buffer
{
    @synchronized (timeLock) {
        //NSLog(@"queuing samples: %d", buffer.samples);
        assert(!isClosing && !isClosed);
        if (buffer.samples > 0) {
            [self queueInput:buffer];
            //NSLog(@"buffered count: %d", [self circularCount]);
            if (!isStarting && !isRunning && !isClosing && !isClosed && samplesQueued >= nBuffers * bufferSize) {
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

-(BOOL)isClosing;
{
    @synchronized (timeLock) {
        return isClosing;
    }
}

-(BOOL)isClosed;
{
    @synchronized (timeLock) {
        return isClosed;
    }
}


-(void)close
{
    @synchronized (timeLock) {
        isClosing = YES;
        shouldClose = YES;
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
    return (float)[self samplesQueued] / self.format.sampleRate;
}

-(float)timeAwaitingPlayback
{
    return [self bufferTailPosition] - [self playbackPosition];
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
            return samplesOutput / self.format.sampleRate;
        } else {
            return samplesPlayed / self.format.sampleRate;
        }
    }
}

-(float)bufferTailPosition
{
    @synchronized (timeLock) {
        return samplesQueued / self.format.sampleRate;
    }
}

#pragma mark - Private methods

-(size_t)circularCount
{
    return (circularTail + circularBufferSize - circularHead) % circularBufferSize;
}

-(Float32)circularRead
{
    Float32 value = circularBuffer[circularHead];
    circularHead = (circularHead + 1) % circularBufferSize;
    return value;
}

-(void)circularWrite:(Float32)value
{
    circularBuffer[circularTail] = value;
    circularTail = (circularTail + 1) % circularBufferSize;
}

-(void)handleQueue:(AudioQueueRef)_queue buffer:(AudioQueueBufferRef)buffer
{
    @synchronized (timeLock) {
        if (shouldClose) {
            //NSLog(@"Stopping queue");
            AudioQueueStop(queue, NO);
            return;
        }
        
        size_t samplesAvailable = samplesQueued - samplesPlayed;
        if (samplesAvailable > 0) {
            //NSLog(@"handleQueue has data");
            
            size_t sampleCount = samplesAvailable;
            if (sampleCount > bufferSize) {
                sampleCount = bufferSize;
            }
            unsigned int channels = self.format.channels;
            size_t channelSize = sampleCount * sampleSize;
            size_t packetSize = channelSize * channels;
            //NSLog(@"channelSize %d | packetSize %d | samples %d", channelSize, packetSize, sampleCount);
            
            Float32 *dest = (Float32 *)buffer->mAudioData;
            for (size_t i = 0; i < sampleCount * channels; i++) {
                dest[i] = [self circularRead];
            }
            samplesPlayed += sampleCount;
            
            buffer->mAudioDataByteSize = (UInt32)packetSize;
            
            throwIfError(^() {
                return AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
            });
        } else {
            NSLog(@"starved for audio!");

            // Close it out when ready
            isClosing = YES;
        }
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
            if (isStarting) {
                isStarting = NO;
            }
            if (isClosing) {
                isClosing = NO;
            }
            if (!isRunning) {
                isClosed = YES;
            }
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
        assert(samplesQueued >= nBuffers * bufferSize);

        isStarting = YES;
        
        [self changeAudioSessionCategory];
        
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

-(void)changeAudioSessionCategory
{
    NSString *category = [[AVAudioSession sharedInstance] category];
    
    // if the current category is Playback or PlayAndRecord, we don't have to change anything
    if ([category isEqualToString:AVAudioSessionCategoryPlayback] || [category isEqualToString:AVAudioSessionCategoryPlayAndRecord]) {
        return;
    }
    
    throwIfNSError(^(NSError **err) {
        // if the current category is Record, set it to PlayAndRecord
        if ([category isEqualToString:AVAudioSessionCategoryRecord]) {
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:err];
            return;
        }
        
        // otherwise we just change it to Playback
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:err];
    });
}

-(void)queueInput:(OGVAudioBuffer *)buffer
{
    @synchronized (timeLock) {
        int samples = buffer.samples;

        assert(samples + [self circularCount] <= circularBufferSize);
        samplesQueued += samples;

        // AudioToolbox wants interleaved
        int channels = self.format.channels;
        float *srcData[channels];
        for (int channel = 0; channel < channels; channel++) {
            srcData[channel] = [buffer PCMForChannel:channel];
        }
        for (int i = 0; i < buffer.samples; i++) {
            for (int channel = 0; channel < channels; channel++) {
                [self circularWrite:srcData[channel][i]];
            }
        }
    }
}

@end
