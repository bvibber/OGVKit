//
//  OGVVideoEncoder.h
//  OGVKit
//
//  Copyright (c) 2016 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

const NSString *OGVVideoEncoderOptionsBitrateKey = @"bitrate";

@implementation OGVVideoEncoder

-(instancetype)initWithFormat:(OGVVideoFormat *)format
{
    self = [self init];
    if (self) {
        _format = format;
    }
    return self;
}

-(OGVPacket *)encodeFrame:(OGVVideoBuffer *)buffer
{
    NSLog(@"encoding not implemented");
}

@end
