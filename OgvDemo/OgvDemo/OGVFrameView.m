//
//  OGVFrameView.m
//  OgvDemo
//
//  Created by Brion on 11/6/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import "OGVFrameView.h"

@implementation OGVFrameView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

- (void)drawFrame:(OGVFrameBuffer *)buffer
{
    self.image = [self imageWithBuffer:buffer];
}

#pragma mark Private methods

static inline int clamp(int i) {
    if (i < 0) {
        return 0;
    } else if (i > 0xff00) {
        return 0xff00;
    } else {
        return i;
    }
}

- (NSData *)convertYCbCrToRGBA:(OGVFrameBuffer *)buffer
{
    int width = buffer.frameWidth;
    int height = buffer.frameHeight;
    int length = width * height * 4;
    int hdec = buffer.hDecimation;
    int vdec = buffer.vDecimation;
    unsigned char *bytes = malloc(length);
    unsigned char *outPtr = bytes;
    
    for (unsigned int y = 0; y < height; y++) {
        int ydec = y >> vdec;
        unsigned char *YPtr = (unsigned char *)buffer.dataY.bytes + y * buffer.strideY;
        unsigned char *CbPtr = (unsigned char *)buffer.dataCb.bytes + ydec * buffer.strideCb;
        unsigned char *CrPtr = (unsigned char *)buffer.dataCr.bytes + ydec * buffer.strideCr;
        for (unsigned int x = 0; x < width; x++) {
            int xdec = x >> hdec;
            int colorY = YPtr[x];
            int colorCb = CbPtr[xdec];
            int colorCr = CrPtr[xdec];
            
            // Quickie YUV conversion
            // https://en.wikipedia.org/wiki/YCbCr#ITU-R_BT.2020_conversion
            unsigned int multY = (298 * colorY);
            *(outPtr++) = clamp((multY + (409 * colorCr) - 223*256)) >> 8;
            *(outPtr++) = clamp((multY - (100 * colorCb) - (208 * colorCr) + 136*256)) >> 8;
            *(outPtr++) = clamp((multY + (516 * colorCb) - 277*256)) >> 8;
            *(outPtr++) = 0;
        }
    }
    
    return [NSData dataWithBytesNoCopy:bytes length:length];
}

- (UIImage *)imageWithBuffer:(OGVFrameBuffer *)buffer
{
    NSData *data = [self convertYCbCrToRGBA:buffer];
    CGDataProviderRef dataProviderRef = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGImageRef imageRef = CGImageCreate(buffer.frameWidth,
                                        buffer.frameHeight,
                                        8 /* bitsPerColorComponent */,
                                        32 /* bitsPerPixel */,
                                        4 * buffer.frameWidth /* bytesPerRow */,
                                        colorSpaceRef,
                                        kCGBitmapByteOrder32Big | kCGImageAlphaNone,
                                        dataProviderRef,
                                        NULL,
                                        YES /* shouldInterpolate */,
                                        kCGRenderingIntentDefault);
    
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    
    CGDataProviderRelease(dataProviderRef);
    CGColorSpaceRelease(colorSpaceRef);
    CGImageRelease(imageRef);
    
    return image;
}

@end
