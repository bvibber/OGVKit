//
//  OGVOutputStream.m
//  OGVKit
//
//  Copyright (c) 2017 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

@implementation OGVOutputStream

-(int64_t)offset
{
    return 0LL;
}

-(BOOL)seekable
{
    return NO;
}

-(void)seek:(int64_t)pos
{
    // no-op
}

-(void)write:(NSData *)data
{
    // no-op
}

-(void)close
{
    // no-op
}

@end
