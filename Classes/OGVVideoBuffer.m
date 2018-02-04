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
{
    CMSampleBufferRef _sampleBuffer;
}

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
        _sampleBuffer = NULL;
    }
    return self;
}

- (instancetype)initWithFormat:(OGVVideoFormat *)format
                  sampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    self = [super init];
    if (self) {
        _format = format;
        _Y = nil;
        _Cb = nil;
        _Cr = nil;
        _timestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer));
        _sampleBuffer = sampleBuffer;
        CFRetain(_sampleBuffer);
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    __block OGVVideoBuffer *copied;
    [self lock:^() {
        copied = [[OGVVideoBuffer alloc] initWithFormat:self.format
                                                      Y:[self.Y copyWithZone:zone]
                                                     Cb:[self.Cb copyWithZone:zone]
                                                     Cr:[self.Cr copyWithZone:zone]
                                              timestamp:self.timestamp];

    }];
    return copied;
}

-(void)dealloc
{
    if (_sampleBuffer) {
        CFRelease(_sampleBuffer);
    }
}

-(void)lock:(OGVVideoBufferLockCallback)block
{
    if (_sampleBuffer) {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(_sampleBuffer);
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        _Y = [[OGVVideoPlane alloc] initWithPixelBuffer:imageBuffer plane:0];
        _Cb = [[OGVVideoPlane alloc] initWithPixelBuffer:imageBuffer plane:1];
        _Cr = [[OGVVideoPlane alloc] initWithPixelBuffer:imageBuffer plane:2];
        @try {
            block();
        } @finally {
            [_Y neuter];
            [_Cb neuter];
            [_Cr neuter];
            _Y = nil;
            _Cb = nil;
            _Cr = nil;
            CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        }
    } else {
        block();
    }
}

-(void)neuter
{
    [_Y neuter];
    [_Cb neuter];
    [_Cr neuter];
    if (_sampleBuffer) {
        CFRelease(_sampleBuffer);
        _sampleBuffer = nil;
    }
}

-(CVPixelBufferRef)copyPixelBufferWithPlane:(OGVVideoPlaneIndex)plane;
{
    __block CVPixelBufferRef pixelBuffer;
    [self lock:^() {
        __block OGVVideoPlane *source;
        switch (plane) {
            case OGVVideoPlaneIndexY:
                pixelBuffer = [self.format createPixelBufferLuma];
                source = self.Y;
                break;
            case OGVVideoPlaneIndexCb:
                pixelBuffer = [self.format createPixelBufferChroma];
                source = self.Cb;
                break;
            case OGVVideoPlaneIndexCr:
                pixelBuffer = [self.format createPixelBufferChroma];
                source = self.Cr;
                break;
            default:
                [NSException raise:@"OGVVideoBufferException"
                            format:@"invalid plane %d", (int)plane];
        }
        
        [source updatePixelBuffer:pixelBuffer];
    }];
    return pixelBuffer;
}

-(CMSampleBufferRef)copyAsSampleBuffer
{
    CVPixelBufferRef pixelBuffer = [self.format createPixelBuffer];
    [self updatePixelBuffer:pixelBuffer];
    
    CMVideoFormatDescriptionRef formatDesc;
    OSStatus ret = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &formatDesc);
    if (ret != 0) {
        @throw [NSException
                exceptionWithName:@"OGVVideoBufferException"
                reason:[NSString stringWithFormat:@"Failed to create CMVideoFormatDescription %d", (int)ret]
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
                reason:[NSString stringWithFormat:@"Failed to create CMSampleBuffer %d", (int)ret]
                userInfo:@{@"CMReturn": @(ret)}];
    }
    
    CFRelease(formatDesc); // now belongs to sampleBuffer
    CFRelease(pixelBuffer); // now belongs to sampleBuffer

    return sampleBuffer;
}

-(void)updatePixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    [self lock:^{
        switch (self.format.pixelFormat) {
            case OGVPixelFormatYCbCr420:
                [self updatePixelBuffer420:pixelBuffer];
                break;
            case OGVPixelFormatYCbCr422:
                [self updatePixelBuffer422:pixelBuffer];
                break;
            case OGVPixelFormatYCbCr444:
                [self updatePixelBuffer444:pixelBuffer];
                break;
        }
    }];
}

-(void)updatePixelBuffer420:(CVPixelBufferRef)pixelBuffer
{
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    int lumaWidth = self.format.lumaWidth;
    int lumaHeight = self.format.lumaHeight;
    int chromaWidth = self.format.chromaWidth;
    int chromaHeight = self.format.chromaHeight;

    size_t lumaInStride = self.Y.stride;
    size_t chromaCbInStride = self.Cb.stride;
    size_t chromaCrInStride = self.Cr.stride;
    const unsigned char *lumaIn = self.Y.data.bytes;
    const unsigned char *chromaCbIn = self.Cb.data.bytes;
    const unsigned char *chromaCrIn = self.Cr.data.bytes;

    size_t lumaOutStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    size_t chromaOutStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
    unsigned char *lumaOut = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    unsigned char *chromaOut = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);

    for (int y = 0; y < lumaHeight; y++) {
        memcpy(lumaOut, lumaIn, lumaWidth);
        lumaIn += lumaInStride;
        lumaOut += lumaOutStride;
    }
    
    for (int y = 0; y < chromaHeight; y++) {
#if defined(__arm64) || defined(__arm)
        // Interleave blocks of 16 pixels...
        const int skip = chromaWidth & ~0xf;
        for (int x = 0; x < skip; x += 16) {
            const uint8x16x2_t tmp = {
                .val = {
                    vld1q_u8(chromaCbIn + x),
                    vld1q_u8(chromaCrIn + x)
                }
            };
            vst2q_u8(chromaOut + x * 2, tmp);
        }
#else
        const int skip = 0;
#endif
        for (int x = skip; x < chromaWidth; x++) {
            const int x2 = x * 2;
            
            chromaOut[x2] = chromaCbIn[x];
            chromaOut[x2 + 1] = chromaCrIn[x];
        }
        chromaCbIn += chromaCbInStride;
        chromaCrIn += chromaCrInStride;
        chromaOut += chromaOutStride;
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

-(void)updatePixelBuffer422:(CVPixelBufferRef)pixelBuffer
{
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    int chromaWidth = self.format.chromaWidth;
    int height = self.format.frameHeight;
    size_t lumaInStride = self.Y.stride;
    size_t chromaCbInStride = self.Cb.stride;
    size_t chromaCrInStride = self.Cr.stride;
    const unsigned char *lumaIn = self.Y.data.bytes;
    const unsigned char *chromaCbIn = self.Cb.data.bytes;
    const unsigned char *chromaCrIn = self.Cr.data.bytes;
    
    size_t outStride = CVPixelBufferGetBytesPerRow(pixelBuffer);
    unsigned char *pixelOut = CVPixelBufferGetBaseAddress(pixelBuffer);
    
    for (int y = 0; y < height; y++) {
#if defined(__arm64) || defined(__arm)
        // Interleave blocks of 32 luma / 16 chroma pixels...
        const int skip = chromaWidth & ~0xf;
        for (int x = 0; x < skip; x += 16) {
            const uint8x16x2_t lumaTmp = vld2q_u8(lumaIn + x * 2);
            const uint8x16x4_t tmp = {
                .val = {
                    lumaTmp.val[0],
                    vld1q_u8(chromaCbIn + x),
                    lumaTmp.val[1],
                    vld1q_u8(chromaCrIn + x)
                }
            };
            vst4q_u8(pixelOut + x * 4, tmp);
        }
#else
        const int skip = 0;
#endif
        // Interleave anything that's left
        for (int x = skip; x < chromaWidth; x++) {
            const int x4 = x * 4;
            const int x2 = x * 2;
            pixelOut[x4] = lumaIn[x2];
            pixelOut[x4 + 1] = chromaCbIn[x];
            pixelOut[x4 + 2] = lumaIn[x2 + 1];
            pixelOut[x4 + 3] = chromaCrIn[x];
        }
        lumaIn += lumaInStride;
        chromaCbIn += chromaCbInStride;
        chromaCrIn += chromaCrInStride;
        pixelOut += outStride;
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

-(void)updatePixelBuffer444:(CVPixelBufferRef)pixelBuffer
{
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    int width = self.format.frameWidth;
    int height = self.format.frameHeight;
    size_t lumaInStride = self.Y.stride;
    size_t chromaCbInStride = self.Cb.stride;
    size_t chromaCrInStride = self.Cr.stride;
    const unsigned char *lumaIn = self.Y.data.bytes;
    const unsigned char *chromaCbIn = self.Cb.data.bytes;
    const unsigned char *chromaCrIn = self.Cr.data.bytes;

    size_t outStride = CVPixelBufferGetBytesPerRow(pixelBuffer);
    unsigned char *pixelOut = CVPixelBufferGetBaseAddress(pixelBuffer);

    for (int y = 0; y < height; y++) {
#if defined(__arm64) || defined(__arm)
        // Interleave blocks of 16 pixels...
        const int skip = width & ~0xf;
        for (int x = 0; x < skip; x += 16) {
            const uint8x16x3_t tmp = {
                .val = {
                    vld1q_u8(lumaIn + x),
                    vld1q_u8(chromaCbIn + x),
                    vld1q_u8(chromaCrIn + x)
                }
            };
            vst3q_u8(pixelOut + x * 3, tmp);
        }
#else
        const int skip = 0;
#endif
        // Interleave anything that's left
        for (int x = skip; x < width; x++) {
            const int x3 = x * 3;
            pixelOut[x3] = lumaIn[x];
            pixelOut[x3 + 1] = chromaCbIn[x];
            pixelOut[x3 + 2] = chromaCrIn[x];
        }
        lumaIn += lumaInStride;
        chromaCbIn += chromaCbInStride;
        chromaCrIn += chromaCrInStride;
        pixelOut += outStride;
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

@end
