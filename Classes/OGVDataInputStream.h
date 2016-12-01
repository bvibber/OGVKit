//
//  OGVDataInputStream.h
//  OGVKit
//
//  Copyright (c) 2016 Brion Vibber. All rights reserved.
//

@interface OGVDataInputStream : OGVInputStream

@property NSData *data;

-(instancetype)initWithData:(NSData *)data;

@end
