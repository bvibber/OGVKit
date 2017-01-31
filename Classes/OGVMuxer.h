//
//  OGVMuxer.h
//  OGVKit
//
//  Copyright (c) 2016 Brion Vibber. All rights reserved.
//


@interface OGVMuxer : NSObject

@property OGVOutputStream *outputStream;
@property OGVAudioFormat *audioFormat;
@property OGVVideoFormat *videoFormat;

-(instancetype)init;

-(void)addAudioTrackFormat:(OGVAudioFormat *)audioFormat;

-(void)addVideoTrackFormat:(OGVVideoFormat *)videoFormat;

-(void)openOutputStream:(OGVOutputStream *)outputStream;

-(void)appendAudioPacket:(OGVPacket *)packet;

-(void)appendVideoPacket:(OGVPacket *)packet;

-(void)close;

@end
