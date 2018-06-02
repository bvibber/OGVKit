//
//  OGVVideoEncoder.h
//  OGVKit
//
//  Copyright (c) 2016-2018 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

const NSString *OGVVideoEncoderOptionsBitrateKey = @"videoBitrate";
const NSString *OGVVideoEncoderOptionsKeyframeIntervalKey = @"keyframeInterval";

@implementation OGVVideoEncoder

-(instancetype)initWithFormat:(OGVVideoFormat *)format
                      options:(NSDictionary *)options;
{
    self = [self init];
    if (self) {
        _format = format;
        _options = options;
        _packets = [[OGVQueue alloc] init];
    }
    return self;
}

-(void)encodeFrame:(OGVVideoBuffer *)buffer
{
    [OGVKit.singleton.logger errorWithFormat:@"encoding not implemented"];
}

-(void)close
{
    // no-op
}

@end
