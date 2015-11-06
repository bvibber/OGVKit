//
//  OGVVideoFormat.m
//  OGVKit
//
//  Created by Brion on 6/21/2015
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

@implementation OGVVideoFormat

- (int)hDecimation
{
    switch (self.pixelFormat) {
        case OGVPixelFormatYCbCr420:
        case OGVPixelFormatYCbCr422:
            return 1;
        case OGVPixelFormatYCbCr444:
            return 0;
        default:
            NSLog(@"Invalid pixel format in hDecimation");
            abort();
    }
}

- (int)vDecimation
{
    switch (self.pixelFormat) {
        case OGVPixelFormatYCbCr420:
            return 1;
        case OGVPixelFormatYCbCr422:
        case OGVPixelFormatYCbCr444:
            return 0;
        default:
            NSLog(@"Invalid pixel format in hDecimation");
            abort();
    }
}

- (int)lumaWidth
{
    return self.frameWidth;
}

- (int)lumaHeight
{
    return self.frameHeight;
}

- (int)chromaWidth
{
    return self.lumaWidth >> [self hDecimation];
}

- (int)chromaHeight
{
    return self.lumaHeight >> [self vDecimation];
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    OGVVideoFormat *other = [[OGVVideoFormat alloc] init];
    other.frameWidth = self.frameWidth;
    other.frameHeight = self.frameHeight;
    other.pictureWidth = self.pictureWidth;
    other.pictureHeight = self.pictureHeight;
    other.pictureOffsetX = self.pictureOffsetX;
    other.pictureOffsetY = self.pictureOffsetY;
    other.pixelFormat = self.pixelFormat;
    return other;
}

@end
