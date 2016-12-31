//
//  OGVVideoFormat.m
//  OGVKit
//
//  Created by Brion on 6/21/2015
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

@interface OGVVideoFormat (Private)
@property int frameWidth;
@property int frameHeight;
@property int pictureWidth;
@property int pictureHeight;
@property int pictureOffsetX;
@property int pictureOffsetY;
@property OGVPixelFormat pixelFormat;
@property OGVColorSpace colorSpace;
@end

@implementation OGVVideoFormat
{
    CVPixelBufferPoolRef samplePool;
    CVPixelBufferPoolRef lumaPool;
    CVPixelBufferPoolRef chromaPool;
}

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

-(void)dealloc
{
    if (samplePool) {
        CFRelease(samplePool);
    }
    if (lumaPool) {
        CFRelease(lumaPool);
    }
    if (chromaPool) {
        CFRelease(chromaPool);
    }
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
    other.colorSpace = self.colorSpace;
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
           (self.pixelFormat == other.pixelFormat) &&
           (self.colorSpace == other.colorSpace);
}

-(instancetype)initWithFrameWidth:(int)frameWidth
                      frameHeight:(int)frameHeight
                     pictureWidth:(int)pictureWidth
                    pictureHeight:(int)pictureHeight
                   pictureOffsetX:(int)pictureOffsetX
                   pictureOffsetY:(int)pictureOffsetY
                      pixelFormat:(OGVPixelFormat)pixelFormat
                       colorSpace:(OGVColorSpace)colorSpace
{
    self = [super init];
    if (self) {
        self.frameWidth = frameWidth;
        self.frameHeight = frameHeight;
        self.pictureWidth = pictureWidth;
        self.pictureHeight = pictureHeight;
        self.pictureOffsetX = pictureOffsetX;
        self.pictureOffsetY = pictureOffsetY;
        self.pixelFormat = pixelFormat;
        self.colorSpace = colorSpace;
    }
    return self;
}
-(instancetype)initWithSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    self = [super init];
    if (self) {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);

        int srcPixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer);
        OGVPixelFormat pixelFormat;
        switch (srcPixelFormat) {
            case kCVPixelFormatType_420YpCbCr8Planar:
            case kCVPixelFormatType_420YpCbCr8PlanarFullRange:
                pixelFormat = OGVPixelFormatYCbCr420;
                break;
            default:
                [NSException raise:@"OGVVideoFormatException"
                            format:@"incompatible pixel format (%d)", srcPixelFormat];
        }

        CGRect cleanRect = CVImageBufferGetCleanRect(imageBuffer);
        
        // @fixme get the colorspace
        return [self initWithFrameWidth:CVPixelBufferGetWidth(imageBuffer)
                            frameHeight:CVPixelBufferGetHeight(imageBuffer)
                           pictureWidth:cleanRect.size.width
                          pictureHeight:cleanRect.size.height
                         pictureOffsetX:cleanRect.origin.x
                         pictureOffsetY:cleanRect.origin.y
                            pixelFormat:pixelFormat
                             colorSpace:OGVColorSpaceDefault];
    }
    return self;
}

/**
 * Allocate a video buffer wrapping existing bytes, leaving pointer
 * lifetime up to the caller. Recommend calling -[OGVVideoBuffer neuter]
 * on the resulting buffer when memory becomes no longer valid.
 */
-(OGVVideoBuffer *)createVideoBufferWithYBytes:(uint8_t *)YBytes
                                       YStride:(size_t)YStride
                                       CbBytes:(uint8_t *)CbBytes
                                      CbStride:(size_t)CbStride
                                       CrBytes:(uint8_t *)CrBytes
                                      CrStride:(size_t)CrStride
                                     timestamp:(double)timestamp
{
    return [[OGVVideoBuffer alloc] initWithFormat:self
                                                Y:[[OGVVideoPlane alloc] initWithBytes:YBytes stride:YStride lines:self.lumaHeight]
                                               Cb:[[OGVVideoPlane alloc] initWithBytes:CbBytes stride:CbStride lines:self.chromaHeight]
                                               Cr:[[OGVVideoPlane alloc] initWithBytes:CrBytes stride:CrStride lines:self.chromaHeight]
                                        timestamp:timestamp];
}

-(OGVVideoBuffer *)createVideoBufferWithSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    return [[OGVVideoBuffer alloc] initWithFormat:self sampleBuffer:sampleBuffer];
}

- (CVPixelBufferRef)createPixelBufferLuma
{
    if (lumaPool == NULL) {
        lumaPool = [self createPixelBufferPoolWithFormat:kCVPixelFormatType_OneComponent8
                                                   width:self.lumaWidth
                                                  height:self.lumaHeight];
    }
    return [self createPixelBufferWithPool:lumaPool
                                     width:self.lumaWidth
                                    height:self.lumaHeight];
}

- (CVPixelBufferRef)createPixelBufferChroma
{
    if (chromaPool == NULL) {
        chromaPool = [self createPixelBufferPoolWithFormat:kCVPixelFormatType_OneComponent8
                                                     width:self.chromaWidth
                                                    height:self.chromaHeight];
    }
    return [self createPixelBufferWithPool:chromaPool
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
    if (samplePool == NULL) {
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
        samplePool = [self createPixelBufferPoolWithFormat:pixelFormat
                                                     width:self.lumaWidth
                                                    height:self.lumaHeight];
    }
    
    return [self createPixelBufferWithPool:samplePool
                                     width:self.lumaWidth
                                    height:self.lumaHeight];
}

@end
