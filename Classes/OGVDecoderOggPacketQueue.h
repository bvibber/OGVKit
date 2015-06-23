//
//  OGVDecoderOggPacketQueue.h
//  OGVKit
//
//  Created by Brion on 6/22/15
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"
#import "OGVDecoderOggPacket.h"

@interface OGVDecoderOggPacketQueue : NSObject

@property (readonly) BOOL empty;

- (void)queue:(OGVDecoderOggPacket *)packet;
- (OGVDecoderOggPacket *)peek;
- (OGVDecoderOggPacket *)dequeue;
- (void)flush;

@end
