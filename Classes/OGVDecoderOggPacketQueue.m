//
//  OGVDecoderOggPacketQueue.m
//  OGVKit
//
//  Created by Brion on 6/22/2015
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import "OGVDecoderOggPacketQueue.h"

@implementation OGVDecoderOggPacketQueue
{
    NSMutableArray *packets;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        packets = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)queue:(OGVDecoderOggPacket *)packet
{
    [packets addObject:packet];
}

- (OGVDecoderOggPacket *)peek
{
    if ([packets count]) {
        return packets[0];
    } else {
        return nil;
    }
}

- (OGVDecoderOggPacket *)dequeue
{
    OGVDecoderOggPacket *packet = [self peek];
    if (packet) {
        [packets removeObjectAtIndex:0];
    }
    return packet;
}

@end
