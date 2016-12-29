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

- (CVPixelBufferRef)createPixelBufferLuma
{
    static CVPixelBufferPoolRef bufferPool = NULL;
    static OGVVideoFormat *poolFormat = nil;
    
    if (bufferPool && ![self isEqual:poolFormat]) {
        CFRelease(bufferPool);
        bufferPool = NULL;
        poolFormat = self;
    }
    if (bufferPool == NULL) {
        bufferPool = [self createPixelBufferPoolWithFormat:kCVPixelFormatType_OneComponent8
                                                     width:self.lumaWidth
                                                    height:self.lumaHeight];
    }
    return [self createPixelBufferWithPool:bufferPool
                                     width:self.lumaWidth
                                    height:self.lumaHeight];
}

- (CVPixelBufferRef)createPixelBufferChroma
{
    static CVPixelBufferPoolRef bufferPool = NULL;
    static OGVVideoFormat *poolFormat = nil;
    
    if (bufferPool && ![self isEqual:poolFormat]) {
        CFRelease(bufferPool);
        bufferPool = NULL;
        poolFormat = self;
    }
    if (bufferPool == NULL) {
        bufferPool = [self createPixelBufferPoolWithFormat:kCVPixelFormatType_OneComponent8
                                                     width:self.chromaWidth
                                                    height:self.chromaHeight];
    }
    return [self createPixelBufferWithPool:bufferPool
                                     width:self.chromaWidth
                                    height:self.chromaHeight];
}

-(CVPixelBufferRef)createPixelBufferWithPool:(CVPixelBufferPoolRef)bufferPool
                                       width:(int)width
                                      height:(int)height
{
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
                               (id)kCVImageBufferCleanApertureWidthKey: @(self.pictureWidth * width / self.frameWidth),
                               (id)kCVImageBufferCleanApertureHeightKey: @(self.pictureHeight * height / self.frameHeight),
                               (id)kCVImageBufferCleanApertureHorizontalOffsetKey: @(((self.frameWidth - self.pictureWidth) / 2 - self.pictureOffsetX) * width / self.frameWidth),
                               (id)kCVImageBufferCleanApertureVerticalOffsetKey: @(((self.frameHeight - self.pictureHeight) / 2 - self.pictureOffsetY) * height / self.frameHeight)
                               };
    CVBufferSetAttachment(imageBuffer,
                          kCVImageBufferCleanApertureKey,
                          (__bridge CFDictionaryRef)aperture,
                          kCVAttachmentMode_ShouldPropagate);
    return imageBuffer;
}

- (CVPixelBufferPoolRef)createPixelBufferPoolWithFormat:(OSType)format
                                                  width:(int)width
                                                 height:(int)height

{
    CVPixelBufferPoolRef bufferPool;
    NSDictionary *poolOpts = @{(id)kCVPixelBufferPoolMinimumBufferCountKey: @4};
    NSDictionary *opts = @{(id)kCVPixelBufferWidthKey: @(width),
                           (id)kCVPixelBufferHeightKey: @(height),
                           (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
                           (id)kCVPixelBufferPixelFormatTypeKey: @(format)};
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
    return bufferPool;
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
        OSType pixelFormat;
        switch (self.pixelFormat) {
            case OGVPixelFormatYCbCr420:
                pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
                break;
            case OGVPixelFormatYCbCr422:
                pixelFormat = kCVPixelFormatType_422YpCbCr8_yuvs;
                break;
            case OGVPixelFormatYCbCr444:
                // Warning: does not render on iOS device with AVSampleBufferDisplayLayer
                pixelFormat = kCVPixelFormatType_444YpCbCr8;
                break;
        }
        bufferPool = [self createPixelBufferPoolWithFormat:pixelFormat
                                                     width:self.lumaWidth
                                                    height:self.lumaHeight];
    }
    
    return [self createPixelBufferWithPool:bufferPool
                                     width:self.lumaWidth
                                    height:self.lumaHeight];
}

@end
