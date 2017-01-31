//
//  OGVMuxer.h
//  OGVKit
//
//  Copyright (c) 2016 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

@implementation OGVPacket

-(instancetype)initWithData:(NSData *)data timestamp:(float)timestamp
{
    self = [self init];
    if (self) {
        self.data = data;
        self.timestamp = timestamp;
    }
    return self;
}

@end

