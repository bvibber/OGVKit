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

NS_INLINE void interleave_chroma(const unsigned char *chromaCbIn, const unsigned char *chromaCrIn, const unsigned char *chromaOut) {
#if defined(__arm64) || defined(__arm)
    const uint8x8x2_t tmp = { val: { vld1_u8(chromaCbIn), vld1_u8(chromaCrIn) } };
    vst2_u8(chromaOut, tmp);
#else
    chromaOut[0] = chromaCbIn[0];
    chromaOut[1] = chromaCrIn[0];
    chromaOut[2] = chromaCbIn[1];
    chromaOut[3] = chromaCrIn[1];
    chromaOut[4] = chromaCbIn[2];
    chromaOut[5] = chromaCrIn[2];
    chromaOut[6] = chromaCbIn[3];
    chromaOut[7] = chromaCrIn[3];
    chromaOut[8] = chromaCbIn[4];
    chromaOut[9] = chromaCrIn[4];
    chromaOut[10] = chromaCbIn[5];
    chromaOut[11] = chromaCrIn[5];
    chromaOut[12] = chromaCbIn[6];
    chromaOut[13] = chromaCrIn[6];
    chromaOut[14] = chromaCbIn[7];
    chromaOut[15] = chromaCrIn[7];
#endif
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
        //unsigned char *chromaOut2 = chromaOut;
        for (int x = chromaXStart; x < chromaXEnd; x += 8) {
            interleave_chroma(chromaCbIn + x, chromaCrIn + x, chromaOut + (x * 2));
            //uint8x8x2_t tmp = { val: { vld1_u8(chromaCbIn + x), vld1_u8(chromaCrIn + x) } };
            //vst2_u8(chromaOut + (x * 2), tmp);
        }
        chromaCbIn += chromaCbInStride;
        chromaCrIn += chromaCrInStride;
        chromaOut += chromaOutStride;
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

@end
