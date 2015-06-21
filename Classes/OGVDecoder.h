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
@property int frameWidth;
@property int frameHeight;
@property float frameRate;
@property int pictureWidth;
@property int pictureHeight;
@property int pictureOffsetX;
@property int pictureOffsetY;
@property int hDecimation;
@property int vDecimation;

@property BOOL hasAudio;
@property int audioChannels;
@property int audioRate;

@property BOOL audioReady;
@property BOOL frameReady;

@property OGVStreamFile *inputStream;

- (BOOL)process;
- (BOOL)decodeFrame;
- (BOOL)decodeAudio;
- (OGVFrameBuffer *)frameBuffer;
- (OGVAudioBuffer *)audioBuffer;
+ (BOOL)canPlayType:(NSString *)type;

+ (void)registerDecoderClass:(Class<OGVDecoder>)decoderClass;
+ (OGVDecoder *)decoderForType:(NSString *)type;

@end
