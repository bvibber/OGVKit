//
//  OGVMuxer.h
//  OGVKit
//
//  Copyright (c) 2016 Brion Vibber. All rights reserved.
//


@interface OGVMuxer : NSObject

-(void)addAudioTrack:(OGVAudioEncoder *)audioEncoder;

-(void)addVideoTrack:(OGVVideoEncoder *)videoEncoder;

-(void)openOutputStream:(OGVOutputStream *)outputStream;

-(void)appendAudioPacket:(OGVPacket *)packet;

-(void)appendVideoPacket:(OGVPacket *)packet;

-(void)close;

@end
