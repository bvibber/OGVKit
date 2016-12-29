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
    OGVColorSpaceBT2020 = 5,
    OGVColorSpaceSRGB = 6
};

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
 * Create a YCbCr CVPixelBuffer compatible with this format, pulling from
 * a pool. Will be suitable for the full image, using appropriate packed format
 * compatible with CMSampleBuffer for display or encoding via AVFoundation.
 *
 * Beware that 4:4:4 buffers may not be compatible with AVFoundation on iOS.
 *
 * Fill with pixels with -[OGVVideoBuffer updatePixelBuffer:]
 *
 * @todo manage the pool sensibly
 */
-(CVPixelBufferRef)createPixelBuffer;

/**
 * Create a CVPixelBuffer compatible with luma planes for this format,
 * pulling from a pool.
 *
 * Fill with pixels with -[OGVVideoPlane updatePixelBuffer:]
 *
 * @todo manage the pool sensibly
 */
-(CVPixelBufferRef)createPixelBufferLuma;

/**
 * Create a CVPixelBuffer compatible with chroma planes for this format,
 * pulling from a pool.
 *
 * Fill with pixels with -[OGVVideoPlane updatePixelBuffer:]
 *
 * @todo manage the pool sensibly
 */
-(CVPixelBufferRef)createPixelBufferChroma;

@end
