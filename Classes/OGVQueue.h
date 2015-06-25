//
//  OGVQueue.h
//  OGVKit
//
//  Created by Brion on 6/22/15
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"
#import "OGVDecoderOggPacket.h"

@interface OGVQueue : NSObject

@property (readonly) BOOL empty;

- (void)queue:(id)object;
- (void)swap:(id)object;
- (id)peek;
- (id)dequeue;
- (void)flush;

@end
