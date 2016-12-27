//
//  OGVVideoFormat.m
//  OGVKit
//
//  Created by Brion on 6/21/2015
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

@implementation OGVVideoFormat

- (int)hDecimation
{
    switch (self.pixelFormat) {
        case OGVPixelFormatYCbCr420:
        case OGVPixelFormatYCbCr422:
            return 1;
        case OGVPixelFormatYCbCr444:
            return 0;
        default:
            NSLog(@"Invalid pixel format in hDecimation");
            abort();
    }
}

- (int)vDecimation
{
    switch (self.pixelFormat) {
        case OGVPixelFormatYCbCr420:
            return 1;
        case OGVPixelFormatYCbCr422:
        case OGVPixelFormatYCbCr444:
            return 0;
        default:
            NSLog(@"Invalid pixel format in hDecimation");
            abort();
    }
}

- (int)lumaWidth
{
    return self.frameWidth;
}

- (int)lumaHeight
{
    return self.frameHeight;
}

- (int)chromaWidth
{
    return self.lumaWidth >> [self hDecimation];
}

- (int)chromaHeight
{
    return self.lumaHeight >> [self vDecimation];
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    OGVVideoFormat *other = [[OGVVideoFormat alloc] init];
    other.frameWidth = self.frameWidth;
    other.frameHeight = self.frameHeight;
    other.pictureWidth = self.pictureWidth;
    other.pictureHeight = self.pictureHeight;
    other.pictureOffsetX = self.pictureOffsetX;
    other.pictureOffsetY = self.pictureOffsetY;
    other.pixelFormat = self.pixelFormat;
    return other;
}

- (BOOL)isEqual:(id)object
{
    if (!object) {
        return NO;
    }
    if ([object class] != [self class]) {
        return NO;
    }
    if (self == object) {
        return YES;
    }
    OGVVideoFormat *other = object;
    return (self.frameWidth == other.frameWidth) &&
           (self.frameHeight == other.frameHeight) &&
           (self.pictureWidth == other.pictureWidth) &&
           (self.pictureHeight == other.pictureHeight) &&
           (self.pictureOffsetX == other.pictureOffsetX) &&
           (self.pictureOffsetY == other.pictureOffsetY) &&
           (self.pixelFormat == other.pixelFormat);
}

-(instancetype)initWithSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    self = [super init];
    if (self) {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);

        int pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer);
        switch (pixelFormat) {
            case kCVPixelFormatType_420YpCbCr8Planar:
                self.pixelFormat = OGVPixelFormatYCbCr420;
                break;
            default:
                [NSException raise:@"OGVVideoFormatException"
                            format:@"incompatible pixel format (%d)", pixelFormat];
        }

        self.frameWidth = CVPixelBufferGetWidth(imageBuffer);
        self.frameHeight = CVPixelBufferGetHeight(imageBuffer);

        CGRect cleanRect = CVImageBufferGetCleanRect(imageBuffer);
        self.pictureWidth = cleanRect.size.width;
        self.pictureHeight = cleanRect.size.height;
        self.pictureOffsetX = cleanRect.origin.x;
        self.pictureOffsetY = cleanRect.origin.y;
    }
    return self;
}

- (CVPixelBufferRef)createPixelBuffer
{
    static CVPixelBufferPoolRef bufferPool = NULL;
    static OGVVideoFormat *poolFormat = nil;

    if (bufferPool && ![self isEqual:poolFormat]) {
        NSLog(@"swapping buffer pools");
        CFRelease(bufferPool);
        bufferPool = NULL;
        poolFormat = self;
    }
    if (bufferPool == NULL) {
        NSNumber *pixelFormat;
        switch (self.pixelFormat) {
            case OGVPixelFormatYCbCr420:
                pixelFormat = @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange);
                break;
            case OGVPixelFormatYCbCr422:
                pixelFormat = @(kCVPixelFormatType_422YpCbCr8_yuvs);
                break;
            case OGVPixelFormatYCbCr444:
                // Warning: does not render on iOS device with AVSampleBufferDisplayLayer
                pixelFormat = @(kCVPixelFormatType_444YpCbCr8);
                break;
        }
        NSDictionary *poolOpts = @{(id)kCVPixelBufferPoolMinimumBufferCountKey: @1};
        NSDictionary *opts = @{(id)kCVPixelBufferWidthKey: @(self.frameWidth),
                               (id)kCVPixelBufferHeightKey: @(self.frameHeight),
                               (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
                               (id)kCVPixelBufferPixelFormatTypeKey: pixelFormat};
        CVReturn ret = CVPixelBufferPoolCreate(NULL,
                                               (__bridge CFDictionaryRef _Nullable)(poolOpts),
                                               (__bridge CFDictionaryRef _Nullable)(opts),
                                               &bufferPool);
        if (ret != kCVReturnSuccess) {
            @throw [NSException
                    exceptionWithName:@"OGVVideoFormatException"
                    reason:[NSString stringWithFormat:@"Failed to create CVPixelBufferPool %d", ret]
                    userInfo:@{@"CVReturn": @(ret)}];
        }
    }
    
    CVImageBufferRef imageBuffer;
    CVReturn ret = CVPixelBufferPoolCreatePixelBuffer(NULL, bufferPool, &imageBuffer);
    if (ret != kCVReturnSuccess) {
        @throw [NSException
                exceptionWithName:@"OGVVideoFormatException"
                reason:[NSString stringWithFormat:@"Failed to create CVPixelBuffer %d", ret]
                userInfo:@{@"CVReturn": @(ret)}];
    }
    
    CVPixelBufferPoolFlush(bufferPool, 0);
    
    // Clean aperture setting doesn't get handled by buffer pool?
    // Set it on each buffer as we get it.
    NSDictionary *aperture = @{
                               (id)kCVImageBufferCleanApertureWidthKey: @(self.pictureWidth),
                               (id)kCVImageBufferCleanApertureHeightKey: @(self.pictureHeight),
                               (id)kCVImageBufferCleanApertureHorizontalOffsetKey: @(-self.pictureOffsetX),
                               (id)kCVImageBufferCleanApertureVerticalOffsetKey: @(-self.pictureOffsetY)
                               };
    CVBufferSetAttachment(imageBuffer,
                          kCVImageBufferCleanApertureKey,
                          (__bridge CFDictionaryRef)aperture,
                          kCVAttachmentMode_ShouldNotPropagate);
    
    return imageBuffer;
}

@end
