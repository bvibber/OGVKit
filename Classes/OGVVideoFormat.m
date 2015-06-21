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

@end
