//
//  OGVMuxer.h
//  OGVKit
//
//  Copyright (c) 2016 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

@implementation OGVPacket

-(instancetype)initWithData:(NSData *)data
                  timestamp:(float)timestamp
                   duration:(float)duration
                   keyframe:(BOOL)keyframe
{
    self = [self init];
    if (self) {
        self.data = data;
        self.timestamp = timestamp;
        self.duration = duration;
        self.keyframe = keyframe;
    }
    return self;
}

@end

