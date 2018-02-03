//
//  OGVQueue.h
//  OGVKit
//
//  Created by Brion on 6/22/15
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

@interface OGVQueue : NSObject

@property (readonly) BOOL empty;

- (void)queue:(id)object;
- (id)peek;
- (id)dequeue;
- (void)flush;
- (id)match:(BOOL(^)(id item))block;

@end
