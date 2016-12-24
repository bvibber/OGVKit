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


static void releasePixelBufferBacking(void *releaseRefCon, const void *dataPtr, size_t dataSize, size_t numberOfPlanes, const void * _Nullable planeAddresses[])
{
    CFTypeRef buf = (CFTypeRef)releaseRefCon;
    CFRelease(buf);
}


static inline void interleave_chroma(unsigned char *chromaCbIn, unsigned char *chromaCrIn, unsigned char *chromaOut) {
#if defined(__arm64) || defined(__arm)
    uint8x8x2_t tmp = { val: { vld1_u8(chromaCbIn), vld1_u8(chromaCrIn) } };
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

static CVPixelBufferPoolRef bufferPool = NULL;
static OGVVideoFormat *poolFormat = nil;

-(CMSampleBufferRef)copyAsSampleBuffer
{
    OGVVideoBuffer *buffer = self;
    
    if (bufferPool && ![buffer.format isEqual:poolFormat]) {
        NSLog(@"swapping buffer pools");
        CFRelease(bufferPool);
        bufferPool = NULL;
        poolFormat = buffer.format;
    }
    if (bufferPool == NULL) {
        NSDictionary *poolOpts = @{(id)kCVPixelBufferPoolMinimumBufferCountKey: @1,
                                   (id)kCVPixelBufferPoolMaximumBufferAgeKey: @1.0};
        NSDictionary *opts = @{(id)kCVPixelBufferWidthKey: @(buffer.format.frameWidth),
                               (id)kCVPixelBufferHeightKey: @(buffer.format.frameHeight),
                               (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
                               (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
        CVReturn ret = CVPixelBufferPoolCreate(NULL,
                                               (__bridge CFDictionaryRef _Nullable)(poolOpts),
                                               (__bridge CFDictionaryRef _Nullable)(opts),
                                               &bufferPool);
        if (ret != kCVReturnSuccess) {
            @throw [NSException
                    exceptionWithName:@"OGVVideoBufferException"
                    reason:[NSString stringWithFormat:@"Failed to create CVPixelBufferPool %d", ret]
                    userInfo:@{@"CVReturn": @(ret)}];
        }
    }
    
    //CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

    CVImageBufferRef imageBuffer;
    //NSDictionary *opts = @{(id)kCVPixelBufferPoolAllocationThresholdKey: @32};
    //OSType ok = CVPixelBufferCreate(NULL, buffer.format.frameWidth, buffer.format.frameHeight, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, (__bridge CFDictionaryRef _Nullable)(opts), &imageBuffer);
    //CVReturn ok = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(NULL,
                                                                      //bufferPool,
                                                                      //(__bridge CFDictionaryRef _Nullable)(opts),
                                                                      //&imageBuffer);
    CVReturn ret = CVPixelBufferPoolCreatePixelBuffer(NULL, bufferPool, &imageBuffer);
    if (ret == kCVReturnWouldExceedAllocationThreshold) {
        NSLog(@"extra flush");
        CVPixelBufferPoolFlush(bufferPool, kCVPixelBufferPoolFlushExcessBuffers);
        ret = CVPixelBufferPoolCreatePixelBuffer(NULL, bufferPool, &imageBuffer);
    }
    if (ret != kCVReturnSuccess) {
        @throw [NSException
                exceptionWithName:@"OGVVideoBufferException"
                reason:[NSString stringWithFormat:@"Failed to create CVPixelBuffer %d", ret]
                userInfo:@{@"CVReturn": @(ret)}];
    }
    
    CVPixelBufferPoolFlush(bufferPool, 0);

    // Clean aperture setting doesn't get handled by buffer pool?
    // Set it on each buffer as we get it.
    NSDictionary *aperture = @{
                               (id)kCVImageBufferCleanApertureWidthKey: @(buffer.format.pictureWidth),
                               (id)kCVImageBufferCleanApertureHeightKey: @(buffer.format.pictureHeight),
                               (id)kCVImageBufferCleanApertureHorizontalOffsetKey: @(-buffer.format.pictureOffsetX),
                               (id)kCVImageBufferCleanApertureVerticalOffsetKey: @(-buffer.format.pictureOffsetY)
                               };
    CVBufferSetAttachment(imageBuffer,
                          kCVImageBufferCleanApertureKey,
                          (__bridge CFDictionaryRef)aperture,
                          kCVAttachmentMode_ShouldNotPropagate);
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    int lumaWidth = buffer.format.lumaWidth;
    int lumaHeight = buffer.format.lumaHeight;
    unsigned char *lumaIn = buffer.Y.data.bytes;
    unsigned char *lumaOut = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
    size_t lumaInStride = buffer.Y.stride;
    size_t lumaOutStride = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
    for (int y = 0; y < lumaHeight; y++) {
        memcpy(lumaOut, lumaIn, lumaWidth);
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
    int widthChopStub = chromaWidth % 8;
    int widthChopped = chromaWidth - widthChopStub;
    int widthChunks = widthChopped / 8;
    for (int y = 0; y < chromaHeight; y++) {
        for (int x = 0; x < widthChopped; x += 8) {
            interleave_chroma(chromaCbIn + x, chromaCrIn + x, chromaOut + (x * 2));
        }
        for (int x = widthChopped; x < chromaWidth; x++) {
            chromaOut[x * 2] = chromaCbIn[x];
            chromaOut[x * 2 + 1] = chromaCrIn[x];
        }
        chromaCbIn += chromaCbInStride;
        chromaCrIn += chromaCrInStride;
        chromaOut += chromaOutStride;
    }
    
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    CMVideoFormatDescriptionRef formatDesc;
    ret = CMVideoFormatDescriptionCreateForImageBuffer(NULL, imageBuffer, &formatDesc);
/*
    NSDictionary *attachments = (__bridge NSDictionary *)CVBufferGetAttachments(imageBuffer, 0);
    NSMutableDictionary *ext = [[NSMutableDictionary alloc] init];
    for (NSString *key in (__bridge NSArray *)CMVideoFormatDescriptionGetExtensionKeysCommonWithImageBuffers()) {
        ext[key] = attachments[key];
        NSLog(@"key: %@ -> %@", key, attachments[key]);
    }
 */
    //ext[(id)kCMFormatDescriptionExtension_CleanAperture] = aperture;
    //ext[(id)kCMFormatDescriptionExtension_PixelAspectRatio] = @1.0;
        
    
    /*
    ret = CMVideoFormatDescriptionCreate(NULL,
                                         CVPixelBufferGetPixelFormatType(imageBuffer),
                                         buffer.format.frameWidth,
                                         buffer.format.frameHeight,
                                         (__bridge CFDictionaryRef _Nullable)(ext),
                                         &formatDesc);
*/
    if (ret != 0) {
        @throw [NSException
                exceptionWithName:@"OGVVideoBufferException"
                reason:[NSString stringWithFormat:@"Failed to create CMVideoFormatDescription %d", ret]
                userInfo:@{@"CMReturn": @(ret)}];
        return NULL;
    }
    
    CMSampleTimingInfo sampleTiming;
    sampleTiming.duration = CMTimeMake((1.0 / 60) * 1000, 1000);
    sampleTiming.presentationTimeStamp = CMTimeMake(buffer.timestamp * 1000, 1000);
    sampleTiming.decodeTimeStamp = kCMTimeInvalid;
    
    CMSampleBufferRef sampleBuffer;
    ret = CMSampleBufferCreateForImageBuffer(NULL, imageBuffer, YES, NULL, NULL, formatDesc, &sampleTiming, &sampleBuffer);
    if (ret != 0) {
        @throw [NSException
                exceptionWithName:@"OGVVideoBufferException"
                reason:[NSString stringWithFormat:@"Failed to create CMSampleBuffer %d", ret]
                userInfo:@{@"CMReturn": @(ret)}];
    }
    
    CFRelease(formatDesc);
    CFRelease(imageBuffer);

    //CFTimeInterval delta = CFAbsoluteTimeGetCurrent() - start;
    //NSLog(@"created CMSampleBuffer in %lf ms", delta * 1000.0);

    return sampleBuffer;
}
@end
