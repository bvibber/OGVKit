//
//  OGVDecoderWebMPacket.h
//  OGVKit
//
//  Created by Brion on 6/24/15
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"
#import <nestegg/nestegg.h>

@interface OGVDecoderWebMPacket : NSObject

/**
 * Encapsulate a nestegg_packet struct pointer.
 *
 * The object takes ownership of the nestegg_packet structure,
 * and will free it when the object is dealloc'd.
 */
- (instancetype)initWithNesteggPacket:(nestegg_packet *)packet;

/**
 * Returns a non-copied NSData wrapper for the data in the 
 * given 'data' item of the packet. If you need to keep this data
 * beyond the lifetime of the packet object, copy it!
 */
- (NSData *)dataAtIndex:(unsigned int)item;

#ifdef OGVKIT_HAVE_VORBIS_DECODER
/**
 * Fill out an ogg_packet structure with the data contained in
 * this packet's first data item, suitable for passing to the
 * Vorbis decoder.
 */
- (void)synthesizeOggPacket:(ogg_packet *)dest;
#endif

@property (readonly) nestegg_packet *nesteggPacket;

@property (readonly) float timestamp;
@property (readonly) unsigned int track;
@property (readonly) unsigned int count;

@property (readonly) unsigned int codecDataCount;
@end
