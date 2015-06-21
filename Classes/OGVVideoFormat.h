//
//  OGVVideoFormat.h
//  OGVKit
//
//  Created by Brion on 6/21/2015.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

typedef NS_ENUM(NSUInteger, OGVPixelFormat) {
    OGVPixelFormatYCbCr420 = 0,
    OGVPixelFormatYCbCr422 = 1,
    OGVPixelFormatYCbCr444 = 2
};

@interface OGVVideoFormat : NSObject

@property int frameWidth;
@property int frameHeight;
@property int pictureWidth;
@property int pictureHeight;
@property int pictureOffsetX;
@property int pictureOffsetY;

@property OGVPixelFormat pixelFormat;

@property (readonly) int lumaWidth;
@property (readonly) int lumaHeight;
@property (readonly) int chromaWidth;
@property (readonly) int chromaHeight;

@end
