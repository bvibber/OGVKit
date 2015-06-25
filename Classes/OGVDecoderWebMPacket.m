//
//  OGVDecoderWebMPacket.m
//  OGVKit
//
//  Created by Brion on 6/24/2015
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import "OGVDecoderWebMPacket.h"

@implementation OGVDecoderWebMPacket

# pragma mark - Public methods

- (instancetype)initWithNesteggPacket:(nestegg_packet *)packet
{
    self = [super init];
    if (self) {
        _nesteggPacket = packet;
    }
    return self;
}

- (void)dealloc
{
    nestegg_free_packet(self.nesteggPacket);
}

- (NSData *)dataAtIndex:(unsigned int)item
{
    unsigned char *data;
    size_t data_size;

    nestegg_packet_data(self.nesteggPacket, item, &data, &data_size);
    return [NSData dataWithBytesNoCopy:data length:data_size freeWhenDone:NO];
}


#ifdef OGVKIT_HAVE_VORBIS_DECODER
- (void)synthesizeOggPacket:(ogg_packet *)dest
{
    assert(self.count == 1);
    NSData *data = [self dataAtIndex:0];
    dest->packet = (unsigned char *)data.bytes;
    dest->bytes = [data length];
    dest->b_o_s = 0;
    dest->e_o_s = 0;
    dest->granulepos = 0; // ?
    dest->packetno = 0; // ?
}
#endif

#pragma mark - getters

-(float)timestamp
{
    uint64_t timestamp;
    nestegg_packet_tstamp(self.nesteggPacket, &timestamp);
    return (float)timestamp / NSEC_PER_SEC;
}

- (unsigned int)count
{
    unsigned int count;
    nestegg_packet_count(self.nesteggPacket, &count);
    return count;
}

@end
