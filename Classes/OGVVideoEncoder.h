//
//  OGVVideoEncoder.h
//  OGVKit
//
//  Copyright (c) 2016 Brion Vibber. All rights reserved.
//

@interface OGVVideoEncoder : NSObject

-(instancetype)initWithFormat:(OGVVideoFormat *)format;
-(OGVPacket *)encodeFrame:(OGVVideoBuffer *)frame;

@end
