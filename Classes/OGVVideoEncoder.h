//
//  OGVVideoEncoder.h
//  OGVKit
//
//  Copyright (c) 2016 Brion Vibber. All rights reserved.
//

extern const NSString *OGVVideoEncoderOptionsBitrateKey;

@interface OGVVideoEncoder : NSObject

@property (readonly) OGVVideoFormat *format;

-(instancetype)initWithFormat:(OGVVideoFormat *)format;
-(OGVPacket *)encodeFrame:(OGVVideoBuffer *)frame;

@end
