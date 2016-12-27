//
//  OGVVideoPlane.h
//  OGVKit
//
//  Created by Brion on 6/21/15.
//  Copyright (c) 2015-2016 Brion Vibber. All rights reserved.
//

/**
 * Represents pixel data in a single plane of a YCbCr planar picture.
 *
 * Warning: video buffer objects provided by a decoder may point
 * to internal decoder memory; if you need to access to the buffer
 * across calls into the decoder, create a copy.
 */
@interface OGVVideoPlane : NSObject <NSCopying>

/**
 * Raw bytes of the plane, wrapped in an NSData.
 */
@property (readonly) NSData *data;

/**
 * Number of bytes to advance as each scan line is processed.
 * YCbCr planar buffers are often wider than the encoded frame width
 * for convenience or performance reasons, so hey that's fun.
 */
@property (readonly) unsigned int stride;

/**
 * Number of scan lines contained.
 */
@property (readonly) unsigned int lines;

/**
 * Create a new plane buffer object wrapping an existing NSData object.
 */
-(instancetype)initWithData:(NSData *)data
                     stride:(unsigned int)stride
                      lines:(unsigned int)lines;

/**
 * Create a new plane buffer object wrapping an existing byte buffer.
 * Caller's responsibility to manage lifetime of the underlying byte buffer.
 */
-(instancetype)initWithBytes:(void *)bytes
                      stride:(unsigned int)stride
                       lines:(unsigned int)lines;

/**
 * Create a new plane buffer object wrapping an existing plane of a
 * CVPixelBuffer in memory. Base address must be locked already.
 * Caller's responsibility to manage lifetime of the underlying lock.
 */
-(instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
                             plane:(unsigned int)plane;

@end
