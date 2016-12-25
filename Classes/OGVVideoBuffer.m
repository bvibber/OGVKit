//
//  OGVVideoBuffer.m
//  OGVKit
//
//  Created by Brion on 11/5/13.
//  Copyright (c) 2013-2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

#if defined(__arm64) || defined(__arm)
#include <arm_neon.h>
#endif

@implementation OGVVideoBuffer

- (instancetype)initWithFormat:(OGVVideoFormat *)format
                             Y:(OGVVideoPlane *)Y
                            Cb:(OGVVideoPlane *)Cb
                            Cr:(OGVVideoPlane *)Cr
                     timestamp:(float)timestamp
{
    self = [super init];
    if (self) {
        _format = format;
        _Y = Y;
        _Cb = Cb;
        _Cr = Cr;
        _timestamp = timestamp;
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    return [[OGVVideoBuffer alloc] initWithFormat:self.format
                                                Y:[self.Y copyWithZone:zone]
                                               Cb:[self.Cb copyWithZone:zone]
                                               Cr:[self.Cr copyWithZone:zone]
                                        timestamp:self.timestamp];
}



-(CMSampleBufferRef)copyAsSampleBuffer
{
    CVPixelBufferRef pixelBuffer = [self.format createPixelBuffer];
    [self updatePixelBuffer:pixelBuffer
                     inRect:CGRectMake(0, 0, self.format.frameWidth, self.format.frameHeight)];
    
    CMVideoFormatDescriptionRef formatDesc;
    OSStatus ret = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &formatDesc);
    if (ret != 0) {
        @throw [NSException
                exceptionWithName:@"OGVVideoBufferException"
                reason:[NSString stringWithFormat:@"Failed to create CMVideoFormatDescription %d", ret]
                userInfo:@{@"CMReturn": @(ret)}];
        return NULL;
    }
    
    CMSampleTimingInfo sampleTiming;
    sampleTiming.duration = CMTimeMake((1.0 / 60) * 1000, 1000);
    sampleTiming.presentationTimeStamp = CMTimeMake(self.timestamp * 1000, 1000);
    sampleTiming.decodeTimeStamp = kCMTimeInvalid;
    
    CMSampleBufferRef sampleBuffer;
    ret = CMSampleBufferCreateForImageBuffer(NULL, pixelBuffer, YES, NULL, NULL, formatDesc, &sampleTiming, &sampleBuffer);
    if (ret != 0) {
        @throw [NSException
                exceptionWithName:@"OGVVideoBufferException"
                reason:[NSString stringWithFormat:@"Failed to create CMSampleBuffer %d", ret]
                userInfo:@{@"CMReturn": @(ret)}];
    }
    
    CFRelease(formatDesc); // now belongs to sampleBuffer
    CFRelease(pixelBuffer); // now belongs to sampleBuffer

    return sampleBuffer;
}

-(void)updatePixelBuffer:(CVPixelBufferRef)pixelBuffer inRect:(CGRect)rect
{
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    int lumaXStart = CGRectGetMinX(rect);
    int lumaXEnd = CGRectGetMaxX(rect);
    int lumaYStart = CGRectGetMinY(rect);
    int lumaYEnd = CGRectGetMaxY(rect);
    int lumaWidth = CGRectGetWidth(rect);

    size_t lumaInStride = self.Y.stride;
    size_t lumaOutStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    unsigned char *lumaIn = self.Y.data.bytes + lumaYStart * lumaInStride;
    unsigned char *lumaOut = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) + lumaYStart * lumaOutStride;
    for (int y = lumaYStart; y < lumaYEnd; y++) {
        memcpy(lumaOut, lumaIn, lumaWidth);
        lumaIn += lumaInStride;
        lumaOut += lumaOutStride;
    }
    
    int chromaXStart = lumaXStart / 2;
    int chromaXEnd = lumaXEnd / 2;
    int chromaYStart = lumaYStart / 2;
    int chromaYEnd = lumaYEnd / 2;
    int chromaWidth = lumaWidth / 2;

    size_t chromaCbInStride = self.Cb.stride;
    size_t chromaCrInStride = self.Cr.stride;
    size_t chromaOutStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
    unsigned char *chromaCbIn = self.Cb.data.bytes + chromaYStart * chromaCbInStride;
    unsigned char *chromaCrIn = self.Cr.data.bytes + chromaYStart * chromaCrInStride;
    unsigned char *chromaOut = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) + chromaYStart * chromaOutStride;
    // let's hope we're padded to a multiple of 8 pixels
    for (int y = chromaYStart; y < chromaYEnd; y++) {
        for (int x = chromaXStart; x < chromaXEnd; x += 8) {
            // Manually inlining this is *slightly* faster than NS_INLINE.
#if defined(__arm64) || defined(__arm)
            const uint8x8x2_t tmp = {
                val: {
                    vld1_u8(chromaCbIn + x),
                    vld1_u8(chromaCrIn + x)
                }
            };
            vst2_u8(chromaOut + (x * 2), tmp);
#else
            const int x2 = x * 2;
            chromaOut[x2] = chromaCbIn[x];
            chromaOut[x2 + 1] = chromaCrIn[x];
            chromaOut[x2 + 2] = chromaCbIn[x + 1];
            chromaOut[x2 + 3] = chromaCrIn[x + 1];
            chromaOut[x2 + 4] = chromaCbIn[x + 2];
            chromaOut[x2 + 5] = chromaCrIn[x + 2];
            chromaOut[x2 + 6] = chromaCbIn[x + 3];
            chromaOut[x2 + 7] = chromaCrIn[x + 3];
            chromaOut[x2 + 8] = chromaCbIn[x + 4];
            chromaOut[x2 + 9] = chromaCrIn[x + 4];
            chromaOut[x2 + 10] = chromaCbIn[x + 5];
            chromaOut[x2 + 11] = chromaCrIn[x + 5];
            chromaOut[x2 + 12] = chromaCbIn[x + 6];
            chromaOut[x2 + 13] = chromaCrIn[x + 6];
            chromaOut[x2 + 14] = chromaCbIn[x + 7];
            chromaOut[x2 + 15] = chromaCrIn[x + 7];
#endif
        }
        chromaCbIn += chromaCbInStride;
        chromaCrIn += chromaCrInStride;
        chromaOut += chromaOutStride;
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

@end
