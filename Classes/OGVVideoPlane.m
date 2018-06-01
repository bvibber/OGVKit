//
//  OGVVideoPlane.m
//  OGVKit
//
//  Created by Brion on 11/5/13.
//  Copyright (c) 2013-2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

@implementation OGVVideoPlane

-(instancetype)initWithData:(NSData *)data
                     stride:(size_t)stride
                      lines:(size_t)lines
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
                      stride:(size_t)stride
                       lines:(size_t)lines
{
    NSData *data = [NSData dataWithBytesNoCopy:bytes
                                        length:stride * lines
                                  freeWhenDone:NO];
    return [self initWithData:data stride:stride lines:lines];
}

-(instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
                             plane:(size_t)plane;
{
    return [self initWithBytes:CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, plane)
                        stride:CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, plane)
                         lines:CVPixelBufferGetHeightOfPlane(pixelBuffer, plane)];
}

-(instancetype) copyWithZone:(NSZone *)zone
{
    return [[OGVVideoPlane alloc] initWithData:[self.data copyWithZone:zone]
                                        stride:self.stride
                                         lines:self.lines];
}

-(void)neuter
{
    _data = nil;
    _stride = 0;
    _lines = 0;
}

-(void)updatePixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    size_t inStride = self.stride;
    const unsigned char *pixelIn = self.data.bytes;

    size_t outStride = CVPixelBufferGetBytesPerRow(pixelBuffer);
    unsigned char *pixelOut = CVPixelBufferGetBaseAddress(pixelBuffer);

    size_t width = MIN(inStride, outStride);
    size_t height = self.lines;
    
    for (int y = 0; y < height; y++) {
        memcpy(pixelOut, pixelIn, width);
        pixelIn += inStride;
        pixelOut += outStride;
    }

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

@end
