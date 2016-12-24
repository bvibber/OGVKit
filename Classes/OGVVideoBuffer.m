//
//  OGVVideoBuffer.m
//  OGVKit
//
//  Created by Brion on 11/5/13.
//  Copyright (c) 2013-2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

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


static void releasePixelBufferBacking(void *releaseRefCon, const void *dataPtr, size_t dataSize, size_t numberOfPlanes, const void * _Nullable planeAddresses[])
{
    CFTypeRef buf = (CFTypeRef)releaseRefCon;
    CFRelease(buf);
}

static CVPixelBufferPoolRef bufferPool = NULL;
static OGVVideoFormat *poolFormat = nil;

-(CMSampleBufferRef)copyAsSampleBuffer
{
    OGVVideoBuffer *buffer = self;
    
    if (bufferPool && ![buffer.format isEqual:poolFormat]) {
        CFRelease(bufferPool);
        bufferPool = NULL;
        poolFormat = buffer.format;
    }
    if (bufferPool == NULL) {
        NSDictionary *poolOpts = @{(id)kCVPixelBufferPoolMinimumBufferCountKey: @1};
        NSDictionary *opts = @{(id)kCVPixelBufferWidthKey: @(buffer.format.frameWidth),
                               (id)kCVPixelBufferHeightKey: @(buffer.format.frameHeight),
                               (id)kCVPixelBufferExtendedPixelsLeftKey: @(buffer.format.pictureOffsetX),
                               (id)kCVPixelBufferExtendedPixelsTopKey: @(buffer.format.pictureOffsetY),
                               (id)kCVPixelBufferExtendedPixelsRightKey: @(buffer.format.frameWidth - buffer.format.pictureWidth - buffer.format.pictureOffsetX),
                               (id)kCVPixelBufferExtendedPixelsBottomKey: @(buffer.format.frameHeight - buffer.format.pictureHeight - buffer.format.pictureOffsetY),
                               (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
                               (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
        CVReturn ret = CVPixelBufferPoolCreate(NULL,
                                               (__bridge CFDictionaryRef _Nullable)(poolOpts),
                                               (__bridge CFDictionaryRef _Nullable)(opts),
                                               &bufferPool);
        if (ret != kCVReturnSuccess) {
            NSLog(@"Failed to create CVPixelBufferPool %d", ret);
            return NULL;
        }
    }
    
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    CVImageBufferRef imageBuffer;
    NSDictionary *opts = @{(id)kCVPixelBufferPoolAllocationThresholdKey: @8};
    //OSType ok = CVPixelBufferCreate(NULL, buffer.format.frameWidth, buffer.format.frameHeight, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, (__bridge CFDictionaryRef _Nullable)(opts), &imageBuffer);
    CVReturn ok = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(NULL,
                                                                      bufferPool,
                                                                      (__bridge CFDictionaryRef _Nullable)(opts),
                                                                      &imageBuffer);
    if (ok != kCVReturnSuccess) {
        NSLog(@"pixel buffer create FAILED %d", ok);
        return NULL;
    }
    
    CVPixelBufferPoolFlush(bufferPool, 0);
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    int lumaWidth = buffer.format.lumaWidth;
    int lumaHeight = buffer.format.lumaHeight;
    unsigned char *lumaIn = buffer.Y.data.bytes;
    unsigned char *lumaOut = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
    size_t lumaInStride = buffer.Y.stride;
    size_t lumaOutStride = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
    for (int y = 0; y < lumaHeight; y++) {
        for (int x = 0; x < lumaWidth; x++) {
            lumaOut[x] = lumaIn[x];
        }
        lumaIn += lumaInStride;
        lumaOut += lumaOutStride;
    }
    
    int chromaWidth = buffer.format.chromaWidth;
    int chromaHeight = buffer.format.chromaHeight;
    unsigned char *chromaCbIn = buffer.Cb.data.bytes;
    unsigned char *chromaCrIn = buffer.Cr.data.bytes;
    unsigned char *chromaOut = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
    size_t chromaCbInStride = buffer.Cb.stride;
    size_t chromaCrInStride = buffer.Cr.stride;
    size_t chromaOutStride = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 1);
    for (int y = 0; y < chromaHeight; y++) {
        for (int x = 0; x < chromaWidth; x++) {
            chromaOut[x * 2] = chromaCbIn[x];
            chromaOut[x * 2 + 1] = chromaCrIn[x];
        }
        chromaCbIn += chromaCbInStride;
        chromaCrIn += chromaCrInStride;
        chromaOut += chromaOutStride;
    }
    
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    CMVideoFormatDescriptionRef formatDesc;
    ok = CMVideoFormatDescriptionCreateForImageBuffer(NULL, imageBuffer, &formatDesc);
    if (ok != 0) {
        NSLog(@"format desc FAILED %d", ok);
        return NULL;
    }
    
    CMSampleTimingInfo sampleTiming;
    sampleTiming.duration = CMTimeMake((1.0 / 60) * 1000, 1000);
    sampleTiming.presentationTimeStamp = CMTimeMake(buffer.timestamp * 1000, 1000);
    sampleTiming.decodeTimeStamp = kCMTimeInvalid;
    
    CMSampleBufferRef sampleBuffer;
    ok = CMSampleBufferCreateForImageBuffer(NULL, imageBuffer, YES, NULL, NULL, formatDesc, &sampleTiming, &sampleBuffer);
    if (ok != 0) {
        NSLog(@"sample buffer FAILED %d", ok);
        return NULL;
    }
    
    CFRelease(formatDesc);
    CFRelease(imageBuffer);

    CFTimeInterval delta = CFAbsoluteTimeGetCurrent() - start;
    NSLog(@"created CMSampleBuffer in %lf ms", delta * 1000.0);

    return sampleBuffer;
}
@end
