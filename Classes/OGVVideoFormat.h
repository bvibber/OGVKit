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
    
    // Supported by Theora and VP8/VP9
    OGVColorSpaceBT709 = 1,
    OGVColorSpaceBT601 = 2,
    
    // These are supported by libvpx
    OGVColorSpaceSMPTE170 = 3,
    OGVColorSpaceSMPTE240 = 4,
    OGVColorSpaceBT2020 = 5
};

@class OGVVideoBuffer;

@interface OGVVideoFormat : NSObject <NSCopying>

@property int frameWidth;
@property int frameHeight;
@property int pictureWidth;
@property int pictureHeight;
@property int pictureOffsetX;
@property int pictureOffsetY;

@property OGVPixelFormat pixelFormat;
@property OGVColorSpace colorSpace;

@property (readonly) int lumaWidth;
@property (readonly) int lumaHeight;
@property (readonly) int chromaWidth;
@property (readonly) int chromaHeight;

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
 * Beware that 4:4:4 buffers may not be compatible with AVFoundation on iOS.
 *
 * Fill with pixels with -[OGVVideoBuffer updatePixelBuffer:]
 *
 * These are created from a pool for the lifetime of the format object, and
 * will be automatically recycled after release.
 */
-(CVPixelBufferRef)createPixelBuffer;

/**
 * Create a CVPixelBuffer compatible with luma planes for this format,
 * pulling from a pool.
 *
 * Fill with pixels with -[OGVVideoPlane updatePixelBuffer:]
 *
 * These are created from a pool for the lifetime of the format object, and
 * will be automatically recycled after release.
 */
-(CVPixelBufferRef)createPixelBufferLuma;

/**
 * Create a CVPixelBuffer compatible with chroma planes for this format,
 * pulling from a pool.
 *
 * Fill with pixels with -[OGVVideoPlane updatePixelBuffer:]
 *
 * These are created from a pool for the lifetime of the format object, and
 * will be automatically recycled after release.
 */
-(CVPixelBufferRef)createPixelBufferChroma;

@end
