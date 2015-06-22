//
//  OGVDecoderOggPacket.m
//  OGVKit
//
//  Created by Brion on 6/22/2015
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import "OGVDecoderOggPacket.h"

@implementation OGVDecoderOggPacket

# pragma mark - Public methods

- (instancetype)initWithOggzPacket:(oggz_packet *)packet
{
    self = [super init];
    if (self) {
        _oggzPacket = [self copyPacket:packet];
    }
    return self;
}

-(ogg_packet *)oggPacket
{
    return &self.oggzPacket->op;
}

- (void)dealloc
{
    [self freePacket:self.oggzPacket];
}

#pragma mark - Private methods

-(oggz_packet *)copyPacket:(oggz_packet *)packet
{
    oggz_packet *dupePacket = malloc(sizeof(oggz_packet));
    memcpy(dupePacket, packet, sizeof(oggz_packet));
    
    void *dupeData = malloc(packet->op.bytes);
    memcpy(dupeData, packet->op.packet, packet->op.bytes);
    dupePacket->op.packet = dupeData;
    
    return dupePacket;
}

-(void)freePacket:(oggz_packet *)packet
{
    free(packet->op.packet);
    free(packet);
}

@end
