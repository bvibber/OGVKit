//
//  OGVDecoder.h
//  OGVKit
//
//  Created by Brion on 11/2/13.
//  Copyright (c) 2013-2015 Brion Vibber. All rights reserved.
//

@class OGVDecoder;

@protocol OGVDecoder <NSObject>
+ (instancetype)alloc;
+ (BOOL)canPlayType:(OGVMediaType *)type;
@end

@interface OGVDecoder : NSObject <OGVDecoder>

@property BOOL dataReady;

/**
 * Contains YES if the target media and its underlying data stream
 * allow seeking; NO if not.
 */
@property (readonly) BOOL seekable;

/**
 * Length of the loaded media segment in seconds, if known;
 * contains INFINITY if duration cannot be determined.
 */
@property (readonly) float duration;

@property BOOL hasVideo;
@property OGVVideoFormat *videoFormat;

@property BOOL hasAudio;
@property OGVAudioFormat *audioFormat;

@property (readonly) BOOL audioReady;
@property (readonly) float audioTimestamp;

@property (readonly) BOOL frameReady;
@property (readonly) float frameTimestamp;

@property OGVInputStream *inputStream;

- (BOOL)process;
- (BOOL)decodeFrameWithBlock:(void (^)(OGVVideoBuffer *frameBuffer))block;
- (BOOL)decodeAudioWithBlock:(void (^)(OGVAudioBuffer *audioBuffer))block;
- (BOOL)seek:(float)seconds;

+ (BOOL)canPlayType:(OGVMediaType *)mediaType;

@end
