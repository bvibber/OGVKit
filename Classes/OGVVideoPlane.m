//
//  OGVVideoPlane.m
//  OGVKit
//
//  Created by Brion on 11/5/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

@implementation OGVVideoPlane

-(instancetype)initWithData:(NSData *)data
                     stride:(unsigned int)stride
                      lines:(unsigned int)lines
{
    self = [super init];
    if (self) {
        assert(data);
        assert([data length] >= stride * lines);
        _data = data;
        _stride = stride;
        _lines = lines;
    }
    return self;
}

-(instancetype)initWithBytes:(void *)bytes
                      stride:(unsigned int)stride
                       lines:(unsigned int)lines
{
    NSData *data = [NSData dataWithBytesNoCopy:bytes
                                        length:stride * lines
                                  freeWhenDone:NO];
    return [self initWithData:data stride:stride lines:lines];
}

-(instancetype) copyWithZone:(NSZone *)zone
{
    return [[OGVVideoPlane alloc] initWithData:[self.data copyWithZone:zone]
                                        stride:self.stride
                                         lines:self.lines];
}

@end
