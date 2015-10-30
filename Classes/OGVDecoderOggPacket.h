//
//  OGVDecoderOggPacket.h
//  OGVKit
//
//  Created by Brion on 6/22/15
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"
#import <ogg/ogg.h>
#import <oggz/oggz.h>

@interface OGVDecoderOggPacket : NSObject

@property (readonly) oggz_packet *oggzPacket;
@property (readonly) ogg_packet *oggPacket;

- (instancetype)initWithOggzPacket:(oggz_packet *)packet;

@end
