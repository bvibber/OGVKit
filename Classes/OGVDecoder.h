//
//  OGVDecoder.h
//  OgvDemo
//
//  Created by Brion on 11/2/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

@class OGVDecoder;

@protocol OGVDecoder <NSObject>
+ (instancetype)alloc;
+ (BOOL)canPlayType:(NSString *)type;
@end

@interface OGVDecoder : NSObject <OGVDecoder>

@property BOOL dataReady;

@property BOOL hasVideo;
@property OGVVideoFormat *videoFormat;

@property BOOL hasAudio;
@property OGVAudioFormat *audioFormat;

@property BOOL audioReady;
@property BOOL frameReady;

@property OGVStreamFile *inputStream;

- (BOOL)process;
- (BOOL)decodeFrame;
- (BOOL)decodeAudio;
- (OGVVideoBuffer *)frameBuffer;
- (OGVAudioBuffer *)audioBuffer;
+ (BOOL)canPlayType:(NSString *)type;

+ (void)registerDecoderClass:(Class<OGVDecoder>)decoderClass;
+ (OGVDecoder *)decoderForType:(NSString *)type;

@end
