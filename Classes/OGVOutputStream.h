//
//  OGVOutputStream.h
//  OGVKit
//
//  Copyright (c) 2017 Brion Vibber. All rights reserved.
//

@interface OGVOutputStream : NSObject

@property (readonly) int64_t offset;
@property (readonly) BOOL seekable;

-(void)seek:(int64_t)pos;
-(void)write:(NSData *)data;
-(void)close;

@end
