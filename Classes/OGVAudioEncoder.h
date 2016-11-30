//
//  OGVAudioEncoder.h
//  OGVKit
//
//  Copyright (c) 2016 Brion Vibber. All rights reserved.
//

@interface OGVAudioEncoder : NSObject

-(instancetype)initWithFormat:(OGVAudioFormat *)format;
-(OGVPacket *)encodeAudio:(OGVAudioBuffer *)buffer;

@end
