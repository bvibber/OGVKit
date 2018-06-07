//
//  OGVVideoBuffer.h
//  OGVKit
//
//  Created by Brion on 11/5/13.
//  Copyright (c) 2013-2015 Brion Vibber. All rights reserved.
//

typedef void (^OGVVideoBufferLockCallback)(void);

typedef enum : NSUInteger {
    OGVVideoPlaneIndexY,
    OGVVideoPlaneIndexCb,
    OGVVideoPlaneIndexCr,
} OGVVideoPlaneIndex;

/**
 * An OGVVideoBuffer represents a YCbCr picture frame.
 *
 * Warning: video buffer objects provided by a decoder may point
 * to internal decoder memory; if you need to access to the buffer
 * across calls into the decoder, create a copy.
 */
@interface OGVVideoBuffer : NSObject <NSCopying>

/**
 * Video format properties necessary to properly intrepret the frame.
 */
@property (readonly) OGVVideoFormat *format;

/**
 * The Y luma plane of the YCbCr picture.
 * Only valid during locking.
 */
@property (readonly) OGVVideoPlane *Y;

/**
 * The Cb chroma plane of the YCbCr picture.
 * Only valid during locking.
 */
@property (readonly) OGVVideoPlane *Cb;

/**
 * The Cr chroma plane of the YCbCr picture.
 * Only valid during locking.
 */
@property (readonly) OGVVideoPlane *Cr;

/**
 * Timestamp of the frame, in seconds on the media stream's timeline.
 *
 * Use this to determine when to play back a decoded frame.
 */
@property (readonly) float timestamp;

/**
 * Duration of the frame, in seconds.
 */
@property (readonly) float duration;

- (instancetype)initWithFormat:(OGVVideoFormat *)format
                             Y:(OGVVideoPlane *)Y
                            Cb:(OGVVideoPlane *)Cb
                            Cr:(OGVVideoPlane *)Cr
                     timestamp:(float)timestamp;

-(instancetype)initWithFormat:(OGVVideoFormat *)format
                 sampleBuffer:(CMSampleBufferRef)sampleBuffer;

/**
 * Lock the data planes in place (they may be in GPU memory)
 */
-(void)lock:(OGVVideoBufferLockCallback)block;

/**
 * "Neuter" a live buffer so it will no longer be accessible.
 */
-(void)neuter;

/**
 * Copy and remix bytes to a GPU-backed CMSampleBuffer,
 * which can then be sent to AVAssetWriter, etc.
 */
-(CMSampleBufferRef)copyAsSampleBuffer;

@end
