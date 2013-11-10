//
//  OGVViewController.m
//  OgvDemo
//
//  Created by Brion on 11/2/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import "OGVAppDelegate.h"
#import "OGVViewController.h"
#import "OGVDecoder.h"

@interface OGVViewController ()

@end

@implementation OGVViewController {
    OGVDecoder *decoder;
    NSURLConnection *connection;
    BOOL doneDownloading;
    BOOL waitingForData;
    BOOL playing;
    
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
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (!playing) {
        playing = YES;
        [self startDownload];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    // todo: pause video?
    if (playing) {
        [connection cancel];
        playing = NO;
    }
    [super viewDidDisappear:animated];
}

- (void)showStatus:(NSString *)status
{
    self.statusLabel.text = status;
}

- (void)processNextFrame
{
    if (!playing) {
        return;
    }
    NSDate *start = [NSDate date];
    BOOL more;
    while (!decoder.frameReady) {
        more = [decoder process];
        if (!more) {
            break;
        }
    }
    NSTimeInterval delta = [[NSDate date] timeIntervalSinceDate:start];
    decodingTime += delta;
    
    if (decoder.frameReady) {
        [self drawBuffer:[decoder frameBuffer]];
        if (!more && doneDownloading) {
            NSLog(@"that was the last frame, done!");
        } else {
            // Don't decode the next frame until we're ready for it...
            NSTimeInterval delta2 = [[NSDate date] timeIntervalSinceDate:start]; // in case frame dequeue took some time?
            double delayInSeconds = (1.0 / decoder.frameRate) - delta2;
            if (delayInSeconds < 0.0) {
                // d'oh
                NSLog(@"slow frame decode!");
                delayInSeconds = 0.0;
            }
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, decodeQueue, ^(void){
                [self processNextFrame];
            });
        }
    } else {
        if (doneDownloading) {
            NSLog(@"ran out of data, no more frames? done!");
        } else {
            // more data to process...
            // tell the downloader to ping us when data comes in
            waitingForData = YES;
            NSLog(@"starved for data!");
        }
    }
}

- (void)loadVideoSample
{
    assert(self.mediaSourceURL != nil);
    NSURLRequest *req = [NSURLRequest requestWithURL:self.mediaSourceURL];
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
- (void)drawBuffer:(OGVFrameBuffer *)buffer
{
    dispatch_async(drawingQueue, ^() {
        NSDate *start = [NSDate date];
        
        [self.frameView drawFrame:buffer];
        
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

#pragma mark NSURLConnectionDataDelegate methods

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    dispatch_async(decodeQueue, ^() {
        NSLog(@"receive input: %lu bytes", (unsigned long)data.length);
        [decoder receiveInput:data];
        if (!decoder.dataReady) {
            // We need to process enough of the file that we can
            // start a timer based on the frame rate...
            while (!decoder.dataReady && [decoder process]) {
                // whee!
            }
            if (decoder.dataReady) {
                NSLog(@"Initializing playback!");
                [self initPlaybackState];
                [self processNextFrame];
            }
        }
        if (waitingForData) {
            waitingForData = NO;
            [self processNextFrame];
        }
    });
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSLog(@"done downloading");
    dispatch_async(decodeQueue, ^() {
        doneDownloading = YES;
    });
}

@end
