//
//  OGVDecoderWebM.m
//  OGVKit
//
//  Created by Brion on 6/17/15.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

#import "OGVKit.h"
#import "OGVQueue.h"
#import "OGVDecoderAV.h"

@implementation OGVDecoderAV
{
    float startTime;

    AVAsset *asset;
    AVAssetTrack *videoTrack;
    AVAssetTrack *audioTrack;

    AVAssetReader *assetReader;
    AVAssetReaderTrackOutput *videoOutput;
    AVAssetReaderTrackOutput *audioOutput;

    OGVQueue *audioBuffers;
    OGVQueue *frameBuffers;
    OGVAudioBuffer *queuedAudio;
    CMSampleBufferRef queuedFrame;
}


-(instancetype)init
{
    self = [super init];
    if (self) {
        startTime = 0;

        asset = nil;
        videoTrack = nil;
        audioTrack = nil;

        assetReader = nil;
        videoOutput = nil;
        audioOutput = nil;

        audioBuffers = [[OGVQueue alloc] init];
        frameBuffers = [[OGVQueue alloc] init];
    }
    return self;
}

-(BOOL)decodeFrame
{
    if ([frameBuffers peek]) {
        if (queuedFrame) {
            CFRelease(queuedFrame);
        }
        queuedFrame = (__bridge CMSampleBufferRef)[frameBuffers dequeue];
        return YES;
    } else {
        return NO;
    }
}

-(BOOL)decodeAudio
{
    if ([audioBuffers peek]) {
        queuedAudio = [audioBuffers dequeue];
        return YES;
    } else {
        return NO;
    }
}

-(BOOL)process
{
    if (!asset) {
        // @fixme this will fail for non-URL input stream types
        [self.inputStream cancel];
        asset = [AVURLAsset URLAssetWithURL:self.inputStream.URL options:@{}];

        // use the first available tracks...
        NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
        NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
        if (videoTracks.count) {
            videoTrack = videoTracks[0];
        }
        if (audioTracks.count) {
            audioTrack = audioTracks[0];
        }
    }
    if (!assetReader) {
        // wait until asset.readable?
        // think it will automatically block unless using async kv wait
        // see https://developer.apple.com/reference/avfoundation/avasynchronouskeyvalueloading?language=objc

        NSError *err;
        assetReader = [AVAssetReader assetReaderWithAsset:asset error:&err];
        if (!assetReader) {
            NSLog(@"failed to init AVAssetReader: %@", err);
            asset = nil;
            return NO;
        }

        if (startTime > 0) {
            assetReader.timeRange = CMTimeRangeMake(CMTimeMakeWithSeconds(startTime, 1000),
                                                    kCMTimePositiveInfinity);
        }

        if (videoTrack) {
            videoOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack
                                                           outputSettings:@{
                                                                            (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
                                                                            }];
            [assetReader addOutput:videoOutput];
            
            self.hasVideo = YES;

            // hacko temp
            CMFormatDescriptionRef desc = (__bridge CMFormatDescriptionRef)(videoTrack.formatDescriptions.firstObject);
            CMVideoDimensions dim = CMVideoFormatDescriptionGetDimensions(desc);
            CGSize size = CMVideoFormatDescriptionGetPresentationDimensions(desc, YES, YES);
            self.videoFormat = [[OGVVideoFormat alloc] init];
            self.videoFormat.frameWidth = dim.width;
            self.videoFormat.frameHeight = dim.height;
            self.videoFormat.pictureWidth = size.width;
            self.videoFormat.pictureHeight = size.height;
            self.videoFormat.pixelFormat = OGVPixelFormatYCbCr420;
        }
        if (audioTrack) {
            audioOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:audioTrack
                                                           outputSettings:@{
                                                                            AVFormatIDKey: @(kAudioFormatLinearPCM),
                                                                            AVLinearPCMBitDepthKey: @32,
                                                                            AVLinearPCMIsFloatKey: @YES,
                                                                            AVLinearPCMIsNonInterleaved: @YES
                                                                            }];
            [assetReader addOutput:audioOutput];

            self.hasAudio = YES;

            CMFormatDescriptionRef desc = (__bridge CMFormatDescriptionRef)(audioTrack.formatDescriptions.firstObject);
            AudioStreamBasicDescription *basic = CMAudioFormatDescriptionGetStreamBasicDescription(desc);
            self.audioFormat = [[OGVAudioFormat alloc] initWithChannels:basic->mChannelsPerFrame sampleRate:basic->mSampleRate];
        }

        if (![assetReader startReading]) {
            NSLog(@"failed to read AVFoundation asset");
        }

        self.dataReady = YES;
        return YES;
    }
    
    if (![frameBuffers peek]) {
        [self doDecodeFrame];
    }
    if (![audioBuffers peek]) {
        [self doDecodeAudio];
    }

    if (![frameBuffers peek] && ![audioBuffers peek]) {
        // eof?
        return NO;
    }
    
    //return YES;
    return NO; // will block
}

- (CMSampleBufferRef)frameBuffer
{
    CMSampleBufferRef buffer = queuedFrame;
    queuedFrame = NULL;
    return buffer;
}

- (OGVAudioBuffer *)audioBuffer
{
    OGVAudioBuffer *buffer = queuedAudio;
    queuedAudio = nil;
    return buffer;
}

-(void)dealloc
{
}

-(void)flush
{
    [frameBuffers flush];
    [audioBuffers flush];
    queuedAudio = nil;
    queuedFrame = nil;
}

- (BOOL)seek:(float)seconds
{
    startTime = seconds;

    // Reset reader state...
    [assetReader cancelReading];
    assetReader = nil;
    videoOutput = nil;
    audioOutput = nil;

    videoTrack = nil;
    audioTrack = nil;
    asset = nil;

    [self flush];
    return YES;
}

#pragma mark - property getters

- (BOOL)frameReady
{
    return [frameBuffers peek] != nil;
}

- (float)frameTimestamp
{
    CMSampleBufferRef buffer = (__bridge CMSampleBufferRef)([frameBuffers peek]);
    if (buffer) {
        CMTime pts = CMSampleBufferGetPresentationTimeStamp(buffer);
        float ts = CMTimeGetSeconds(pts);
        return ts;
    } else {
        return -1;
    }
}

- (BOOL)audioReady
{
    return [audioBuffers peek] != nil;
}

- (float)audioTimestamp
{
    OGVAudioBuffer *buffer = [audioBuffers peek];
    if (buffer) {
        return buffer.timestamp;
    } else {
        return -1;
    }
}

-(BOOL)seekable
{
    return self.dataReady && (videoOutput || audioOutput);
}

-(float)duration
{
    if (asset) {
        return CMTimeGetSeconds(asset.duration);
    }
    return INFINITY;
}

#pragma mark - private methods

- (BOOL)doDecodeFrame
{
    if (videoOutput) {
        CMSampleBufferRef sample = [videoOutput copyNextSampleBuffer];
        if (sample) {
            [frameBuffers queue:(__bridge id)(sample)];
            return YES;
        }
    }
    return NO;
}

-(BOOL)doDecodeAudio
{
    if (audioOutput) {
        CMSampleBufferRef sample = [audioOutput copyNextSampleBuffer];
        if (sample) {
            [audioBuffers queue:[self convertAudioSample:sample]];
            CFRelease(sample); // ???
            return YES;
        }
    }
    return NO;
}

- (OGVAudioBuffer *)convertAudioSample:(CMSampleBufferRef)sample
{
    // @fixme reuse the format?
    CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sample);
    AudioStreamBasicDescription *audioDesc = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc);
    int channels = audioDesc->mChannelsPerFrame;
    OGVAudioFormat *format = [[OGVAudioFormat alloc] initWithChannels:channels
                                                           sampleRate:audioDesc->mSampleRate];
    
    float time = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample));
    CMItemCount samples = CMSampleBufferGetNumSamples(sample);

    CMBlockBufferRef buffer = CMSampleBufferGetDataBuffer(sample);
    char *charPtr;
    OSStatus ret = CMBlockBufferGetDataPointer(buffer, 0, NULL, NULL, &charPtr);
    if (ret != kCMBlockBufferNoErr) {
        NSLog(@"CMBlockBufferGetDataPointer failed %d", ret);
    }
    
    float *floatPtr = (float *)charPtr;
    float **channelPtrs = malloc((sizeof (float*)) * channels);
    for (int i = 0; i < channels; i++) {
        channelPtrs[i] = &floatPtr[i * samples];
    }
    OGVAudioBuffer *audioBuffer = [[OGVAudioBuffer alloc] initWithPCM:channelPtrs
                                                              samples:samples
                                                               format:format
                                                            timestamp:time];
    free(channelPtrs);

    return audioBuffer;

}
#pragma mark - class methods

+ (BOOL)canPlayType:(OGVMediaType *)mediaType
{
    return [AVURLAsset isPlayableExtendedMIMEType:[mediaType asString]];
}

@end
