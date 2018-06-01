//
//  OGVQueue.m
//  OGVKit
//
//  Created by Brion on 6/22/2015
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import "OGVQueue.h"

@implementation OGVQueue
{
    NSMutableArray *items;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        items = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)queue:(id)object
{
    [items addObject:object];
}

- (void)swap:(id)object
{
    items[0] = object;
}

- (id)peek
{
    if (self.empty) {
        return nil;
    } else {
        return items[0];
    }
}

- (id)dequeue
{
    id item = [self peek];
    if (item) {
        [items removeObjectAtIndex:0];
    }
    return item;
}

- (void)flush
{
    [items removeAllObjects];
}

- (BOOL)empty
{
    return ([items count] == 0);
}

- (id)match:(BOOL(^)(id item))block
{
    for (id item in items) {
        if (block(item)) {
            return item;
        }
    }
    return nil;
}

@end
