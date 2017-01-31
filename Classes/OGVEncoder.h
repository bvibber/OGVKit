//
//  OGVEncoder.h
//  OGVKit
//
//  Copyright (c) 2017 Brion Vibber. All rights reserved.
//


@interface OGVEncoder : NSObject

-(instancetype)initWithMediaType:(OGVMediaType *)mediaType;

-(void)addVideoTrackFormat:(OGVVideoFormat *)videoFormat
                   options:(NSDictionary *)options;

-(void)addAudioTrackFormat:(OGVAudioFormat *)audioFormat
                   options:(NSDictionary *)options;

-(void)openOutputStream:(OGVOutputStream *)outputStream;

-(void)encodeAudio:(OGVAudioBuffer *)buffer;

-(void)encodeFrame:(OGVVideoBuffer *)buffer;

-(void)close;

@end


