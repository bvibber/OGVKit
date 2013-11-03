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
    NSTimer *timer;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // In real life, don't do any of this on the main thread!
    [self startPlayback];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)startPlayback
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
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    // Quickie loop through the rest
    timer = [NSTimer scheduledTimerWithTimeInterval:(1.0f / decoder.frameRate) target:self selector:@selector(processNextFrame) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (timer) {
        [timer invalidate];
        timer = nil;
    }
    [super viewDidDisappear:animated];
}

- (void)processNextFrame
{
    if (![decoder process]) {
        [timer invalidate];
        timer = nil;
        NSLog(@"done!");
    }
}

- (NSData *)loadVideoSample
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"samples/Peacock_Mating_Call" ofType:@"ogv"];
    return [NSData dataWithContentsOfFile:path];
}

// Incredibly inefficient \o/
- (void)drawBuffer:(OGVFrameBuffer)buffer
{
    NSData *data = [self convertYCbCrToRGBA:buffer];
    CGDataProviderRef dataProviderRef = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGImageRef imageRef = CGImageCreate(decoder.frameWidth,
                                        decoder.frameHeight,
                                        8 /* bitsPerColorComponent */,
                                        32 /* bitsPerPixel */,
                                        4 * decoder.frameWidth /* bytesPerRow */,
                                        colorSpaceRef,
                                        kCGBitmapByteOrder32Big | kCGImageAlphaNone,
                                        dataProviderRef,
                                        NULL,
                                        YES /* shouldInterpolate */,
                                        kCGRenderingIntentDefault);

    UIImage *image = [UIImage imageWithCGImage:imageRef];
    [self performSelectorOnMainThread:@selector(drawImage:) withObject:image waitUntilDone:YES];
    
    CGDataProviderRelease(dataProviderRef);
    CGColorSpaceRelease(colorSpaceRef);
    CGImageRelease(imageRef);
}

- (void)drawImage:(UIImage *)image
{
    self.imageView.image = image;
}

static int clamp(int i) {
    if (i < 0) {
        return 0;
    } else if (i > 0xff00) {
        return 0xff00;
    } else {
        return i;
    }
}

- (NSData *)convertYCbCrToRGBA:(OGVFrameBuffer)buffer
{
    int width = decoder.frameWidth;
    int height = decoder.frameHeight;
    int length = width * height * 4;
    int hdec = decoder.hDecimation;
    int vdec = decoder.vDecimation;
    unsigned char *bytes = malloc(length);
    unsigned char *outPtr = bytes;
    
    for (unsigned int y = 0; y < height; y++) {
        int ydec = y >> vdec;
        unsigned char *YPtr = buffer.YData + y * buffer.YStride;
        unsigned char *CbPtr = buffer.CbData + ydec * buffer.CbStride;
        unsigned char *CrPtr = buffer.CrData + ydec * buffer.CrStride;
        for (unsigned int x = 0; x < width; x++) {
            int xdec = x >> hdec;
            int colorY = YPtr[x];
            int colorCb = CbPtr[xdec];
            int colorCr = CrPtr[xdec];

            // Quickie YUV conversion
            // https://en.wikipedia.org/wiki/YCbCr#ITU-R_BT.2020_conversion
            unsigned int multY = (298 * colorY);
            *(outPtr++) = clamp((multY + (409 * colorCr) - 223*256)) >> 8;
            *(outPtr++) = clamp((multY - (100 * colorCb) - (208 * colorCr) + 136*256)) >> 8;
            *(outPtr++) = clamp((multY + (516 * colorCb) - 277*256)) >> 8;
            *(outPtr++) = 0;
        }
    }
    
    return [NSData dataWithBytesNoCopy:bytes length:length];
}

@end
