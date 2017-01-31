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

-(instancetype)initWithOutputStream:(OGVOutputStream *)outputStream
                        audioFormat:(OGVAudioFormat *)audioFormat
                        videoFormat:(OGVVideoFormat *)videoFormat;
-(void)appendAudioPacket:(OGVPacket *)packet;
-(void)appendVideoPacket:(OGVPacket *)packet;
-(void)close;

@end
