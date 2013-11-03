//
//  OGVViewController.m
//  OgvDemo
//
//  Created by Brion on 11/2/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import "OGVViewController.h"
#import "OGVDecoder.h"

@interface OGVViewController ()

@end

@implementation OGVViewController {
    OGVDecoder *decoder;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // In real life, don't do any of this on the main thread!
    [self loadFirstFrame];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadFirstFrame
{
    decoder = [[OGVDecoder alloc] init];

    NSData *data = [self loadVideoSample];
    [decoder receiveInput:data];

    while (!decoder.dataReady && [decoder process]) {
        // whee!
    }
    
    __unsafe_unretained typeof(self) weakSelf = self; // is this *really* necessary?
    decoder.onframe = ^(OGVFrameBuffer buffer) {
        [weakSelf drawBuffer:buffer];
    };
    [decoder process];
    decoder.onframe = nil;
}

- (NSData *)loadVideoSample
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"samples/Peacock_Mating_Call" ofType:@"ogv"];
    return [NSData dataWithContentsOfFile:path];
}

- (void)drawBuffer:(OGVFrameBuffer)buffer
{
    NSData *data = [self convertYCbCrToRGBA:buffer];
    CGDataProviderRef dataProviderRef = CGDataProviderCreateWithData(NULL, data.bytes, data.length, nil);
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGImageRef imageRef = CGImageCreate(decoder.frameWidth,
                                        decoder.frameHeight,
                                        8 /* bitsPerColorComponent */,
                                        32 /* bitsPerPixel */,
                                        4 * decoder.frameWidth /* bytesPerRow */,
                                        colorSpaceRef,
                                        kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast,
                                        dataProviderRef,
                                        NULL,
                                        YES /* shouldInterpolate */,
                                        kCGRenderingIntentDefault);

    self.imageView.image = [UIImage imageWithCGImage:imageRef];

    CGDataProviderRelease(dataProviderRef);
    CGColorSpaceRelease(colorSpaceRef);
    CGImageRelease(imageRef);
}

- (NSData *)convertYCbCrToRGBA:(OGVFrameBuffer)buffer
{
    unsigned int width = decoder.frameWidth,
        height = decoder.frameHeight,
        length = width * height * 4;
    unsigned char *bytes = malloc(length),
        *inptr = buffer.YData,
        *outptr = bytes;
    
    for (unsigned int y = 0; y < height; y++) {
        inptr = buffer.YData + y * buffer.YStride;
        for (unsigned int x = 0; x < width; x++) {
            // As temp hack, just grayscale
            *(outptr++) = *inptr;
            *(outptr++) = *inptr;
            *(outptr++) = *inptr;
            *(outptr++) = 255;
            inptr++;
        }
    }
    
    return [NSData dataWithBytesNoCopy:bytes length:length];
}

@end
