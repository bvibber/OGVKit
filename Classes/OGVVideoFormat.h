//
//  OGVVideoFormat.h
//  OGVKit
//
//  Created by Brion on 6/21/2015.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

typedef NS_ENUM(NSUInteger, OGVPixelFormat) {
    OGVPixelFormatYCbCr420 = 0,
    OGVPixelFormatYCbCr422 = 1,
    OGVPixelFormatYCbCr444 = 2
};

typedef NS_ENUM(NSUInteger, OGVColorSpace) {
    OGVColorSpaceDefault = 0,

    OGVColorSpaceBT601 = 1,    // Theora, VP8, VP9
    OGVColorSpaceBT601BG = 2,  // Theora

    // Supported by VP8/VP9
    OGVColorSpaceBT709 = 3,    // VP9
    OGVColorSpaceSMPTE170 = 4, // VP9
    OGVColorSpaceSMPTE240 = 5, // VP9
    OGVColorSpaceBT2020 = 6,   // VP9
    OGVColorSpaceSRGB = 7      // VP9 profile 1 & 3 only
};

@class OGVVideoBuffer;

@interface OGVVideoFormat : NSObject <NSCopying>

@property (readonly) int frameWidth;
@property (readonly) int frameHeight;
@property (readonly) int pictureWidth;
@property (readonly) int pictureHeight;
@property (readonly) int pictureOffsetX;
@property (readonly) int pictureOffsetY;
@property (readonly) OGVPixelFormat pixelFormat;
@property (readonly) OGVColorSpace colorSpace;

@property (readonly) int lumaWidth;
@property (readonly) int lumaHeight;
@property (readonly) int chromaWidth;
@property (readonly) int chromaHeight;

/**
 * Initialize with given values
 */
-(instancetype)initWithFrameWidth:(int)frameWidth
                      frameHeight:(int)frameHeight
                     pictureWidth:(int)pictureWidth
                    pictureHeight:(int)pictureHeight
                   pictureOffsetX:(int)pictureOffsetX
                   pictureOffsetY:(int)pictureOffsetY
                      pixelFormat:(OGVPixelFormat)pixelFormat
                       colorSpace:(OGVColorSpace)colorSpace;
/**
 * Initialize format properties to match an existing CMSampleBuffer.
 */
-(instancetype)initWithSampleBuffer:(CMSampleBufferRef)sampleBuffer;

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
                                     timestamp:(double)timestamp;

/**
 * Allocate a video buffer backed by a CMSampleBuffer; only supports
 * uncompressed buffers using kCVPixelFormatType_420YpCbCr8Planar or
 * kCVPixelFormatType_420YpCbCr8PlanarFullRange pixel formats.
 *
 * Locking/unlocking of underlying bytes must be done using the
 * -[OGVVideoBuffer lock:] method to get at the buffer's planes.
 */
-(OGVVideoBuffer *)createVideoBufferWithSampleBuffer:(CMSampleBufferRef)sampleBuffer;

/**
 * Create a YCbCr CVPixelBuffer compatible with this format, pulling from
 * a pool. Will be suitable for the full image, using appropriate packed format
 * compatible with CMSampleBuffer for display or encoding via AVFoundation.
 *
 * Beware that 4:2:2 and 4:4:4 buffers don't work reliably on iOS 10 and lower.
 *
 * Fill with pixels with -[OGVVideoBuffer updatePixelBuffer:]
 *
 * These are created from a pool for the lifetime of the format object, and
 * will be automatically recycled after release.
 */
-(CVPixelBufferRef)createPixelBuffer;


@end
