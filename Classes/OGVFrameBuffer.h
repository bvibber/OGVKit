//
//  OGVFrameBuffer.h
//  OgvDemo
//
//  Created by Brion on 11/5/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

@interface OGVFrameBuffer : NSObject

@property OGVVideoFormat *format;

@property NSData *dataY;
@property NSData *dataCb;
@property NSData *dataCr;

@property unsigned int strideY;
@property unsigned int strideCb;
@property unsigned int strideCr;

@property float timestamp;

@end
