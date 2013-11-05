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
    NSURLConnection *connection;
    BOOL doneDownloading;
    
    dispatch_queue_t decodeQueue;
    dispatch_queue_t drawingQueue;
    
    // Stats
    double pixelsPerFrame;
    double targetPixelRate;
    double pixelsProcessed;
    
    NSTimeInterval decodingTime;
    double averageDecodingRate;
    
    NSTimeInterval drawingTime;
    double averageDrawingRate;
    
    NSDate *lastStatsUpdate;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self startDownload];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)startDownload
{
    decoder = [[OGVDecoder alloc] init];

    // decode on background thread
    decodeQueue = dispatch_queue_create("Decoder", NULL);

    // draw on UI thread
    drawingQueue = dispatch_get_main_queue();

    [self loadVideoSample];

    __unsafe_unretained typeof(self) weakSelf = self; // is this *really* necessary?
    __unsafe_unretained typeof(drawingQueue) weakDrawingQueue = drawingQueue;
    decoder.onframe = ^(OGVFrameBuffer buffer) {
        dispatch_async(weakDrawingQueue, ^() {
            [weakSelf drawBuffer:buffer];
        });
    };
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (decoder && decoder.dataReady) {
        [self startTimer];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self stopTimer];
    [super viewDidDisappear:animated];
}

- (void)showStatus:(NSString *)status
{
    self.statusLabel.text = status;
}

- (void)startTimer
{
    [self stopTimer];
    timer = [NSTimer scheduledTimerWithTimeInterval:(1.0f / decoder.frameRate) target:self selector:@selector(processNextFrame) userInfo:nil repeats:YES];
}

- (void)stopTimer
{
    if (timer) {
        [timer invalidate];
        timer = nil;
    }
}

- (void)processNextFrame
{
    dispatch_async(decodeQueue, ^() {
        NSDate *start = [NSDate date];
        BOOL more = [decoder process];
        NSTimeInterval delta = [[NSDate date] timeIntervalSinceDate:start];
        decodingTime += delta;
        
        if (more) {
            // more data to process...
        } else {
            NSLog(@"no more data to process");
            if (doneDownloading) {
                [timer invalidate];
                timer = nil;
                NSLog(@"done downloading too, stopping!");
            }
        }
    });
}

- (void)loadVideoSample
{
    NSURL *url = [NSURL URLWithString:@"https://upload.wikimedia.org/wikipedia/commons/3/3f/Jarry_-_M%C3%A9tro_de_Montr%C3%A9al_%28640%C3%97360%29.ogv"];
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    connection = [NSURLConnection connectionWithRequest:req delegate:self];
}

- (void)initPlaybackState
{
    assert(decoder.dataReady);

    [self showStatus:@"Starting playback"];

    // Number of pixels per second we must decode and draw to keep up
    pixelsPerFrame = decoder.frameWidth * decoder.frameHeight;
    targetPixelRate = pixelsPerFrame * decoder.frameRate;
    
    pixelsProcessed = 0;

    decodingTime = 0;
    averageDecodingRate = 0;

    drawingTime = 0;
    averageDrawingRate = 0;
}

#pragma mark Drawing methods

// Incredibly inefficient \o/
- (void)drawBuffer:(OGVFrameBuffer)buffer
{
    dispatch_async(drawingQueue, ^() {
        NSDate *start = [NSDate date];
        
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
        [self drawImage:image];
        
        CGDataProviderRelease(dataProviderRef);
        CGColorSpaceRelease(colorSpaceRef);
        CGImageRelease(imageRef);
        
        NSTimeInterval delta = [[NSDate date] timeIntervalSinceDate:start];
        drawingTime += delta;

        pixelsProcessed += pixelsPerFrame;
        [self updateStats];
    });
}

- (void)updateStats
{
    NSDate *now = [NSDate date];
    if (lastStatsUpdate == nil || [now timeIntervalSinceDate:lastStatsUpdate] > 1.0) {
        averageDecodingRate = pixelsProcessed / decodingTime;
        averageDrawingRate = pixelsProcessed / drawingTime;

        double megapixel = 1000000.0;
        NSString *statusLine = [NSString stringWithFormat:@"%0.2lf MP/s decoded, %0.2lf MP/s drawn, %0.2lf MP/s target",
                                averageDecodingRate / megapixel,
                                averageDrawingRate / megapixel,
                                targetPixelRate / megapixel];

        lastStatsUpdate = now;
        [self showStatus:statusLine];
        NSLog(@"%@", statusLine);
    }
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


#pragma mark NSURLConnectionDataDelegate methods

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    NSLog(@"receive input: %d bytes", data.length);
    [decoder receiveInput:data];
    
    if (!decoder.dataReady) {
        // We need to process enough of the file that we can
        // start a timer based on the frame rate...
        while (!decoder.dataReady && [decoder process]) {
            // whee!
        }
        if (decoder.dataReady) {
            [self initPlaybackState];
            [self startTimer];
        }
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSLog(@"done downloading");
    doneDownloading = YES;
}

@end
