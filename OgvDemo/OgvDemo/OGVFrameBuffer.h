//
//  OGVFrameBuffer.h
//  OgvDemo
//
//  Created by Brion on 11/5/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OGVFrameBuffer : NSObject

@property int frameWidth;
@property int frameHeight;
@property int pictureWidth;
@property int pictureHeight;
@property int pictureOffsetX;
@property int pictureOffsetY;
@property int hDecimation;
@property int vDecimation;

@property NSData *dataY;
@property NSData *dataCb;
@property NSData *dataCr;

@property unsigned int strideY;
@property unsigned int strideCb;
@property unsigned int strideCr;

@end
