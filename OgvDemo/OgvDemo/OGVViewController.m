//
//  OGVViewController.m
//  OgvDemo
//
//  Created by Brion on 11/2/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import "OGVAppDelegate.h"
#import "OGVViewController.h"
#import <OgvKit/OgvKit.h>

typedef enum {
    OGVPlaybackResolution160p = 0,
    OGVPlaybackResolution360p = 1,
    OGVPlaybackResolution480p = 2,
    OGVPlaybackResolutionOrig = 3
} OGVPlaybackResolution;

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
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        NSLog(@"Registering...");
        [[NSNotificationCenter defaultCenter] addObserverForName:@"OGVPlayerOpenMedia" object:[UIApplication sharedApplication] queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            
            NSLog(@"got OGVPlayerOpenMedia notification");
            
            assert(note.userInfo[@"mediaSource"]);
            
            [self stopWithBlock:^() {
                self.mediaSource = note.userInfo[@"mediaSource"];
                playing = YES;
                [self startDownload];
            }];
        }];
    }
}

- (void)setMediaSource:(OGVCommonsMediaFile *)mediaSource
{
    _mediaSource = mediaSource;

    [self.resolutionPicker setEnabled:[self.mediaSource hasDerivativeForHeight:160]
                    forSegmentAtIndex:OGVPlaybackResolution160p];
    [self.resolutionPicker setEnabled:[self.mediaSource hasDerivativeForHeight:360]
                    forSegmentAtIndex:OGVPlaybackResolution360p];
    [self.resolutionPicker setEnabled:[self.mediaSource hasDerivativeForHeight:480]
                    forSegmentAtIndex:OGVPlaybackResolution480p];
    [self.resolutionPicker setEnabled:[self.mediaSource isOgg]
                    forSegmentAtIndex:OGVPlaybackResolutionOrig];

    // Bump resolution down if the currently selected one isn't available?
    if (self.resolutionPicker.selectedSegmentIndex == UISegmentedControlNoSegment) {
        for (NSInteger i = OGVPlaybackResolution480p; i >= OGVPlaybackResolution160p; i--) {
            if ([self.resolutionPicker isEnabledForSegmentAtIndex:i]) {
                self.resolutionPicker.selectedSegmentIndex = i;
            }
        }
    }
    // Try original if there wasn't one of those...
    if (self.resolutionPicker.selectedSegmentIndex == UISegmentedControlNoSegment) {
        if ([self.resolutionPicker isEnabledForSegmentAtIndex:OGVPlaybackResolutionOrig]) {
            self.resolutionPicker.selectedSegmentIndex = OGVPlaybackResolutionOrig;
        }
    }
    if (self.resolutionPicker.selectedSegmentIndex == UISegmentedControlNoSegment) {
        NSLog(@"WHAAAAAT still not selected");
    }
    self.mediaSourceURL = [self selectPickedResolutionURL];
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

- (void)stopWithBlock:(void (^)())completionBlock
{
    if (playing) {
        dispatch_async(decodeQueue, ^() {
            if (!doneDownloading) {
                [connection cancel];
            }
            if (playing) {
                playing = NO;
            }
            decoder = nil;
            connection = nil;
            dispatch_async(dispatch_get_main_queue(), completionBlock);
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), completionBlock);
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (self.mediaSource) {
        if (!playing) {
            playing = YES;
            self.mediaSourceURL = [self selectPickedResolutionURL];
            [self startDownload];
        }
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
    //self.statusLabel.text = status;
    NSLog(@"%@", status);
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
    if (self.mediaSourceURL) {
        NSURLRequest *req = [NSURLRequest requestWithURL:self.mediaSourceURL];
        connection = [NSURLConnection connectionWithRequest:req delegate:self];
    } else {
        NSLog(@"Nothing to play");
    }
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
        //NSLog(@"receive input: %lu bytes", (unsigned long)data.length);
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

- (IBAction)resolutionPicked:(UISegmentedControl *)sender {
    NSURL *url = [self selectPickedResolutionURL];
    NSLog(@"picked target: %@", url);
    if (url && ![url isEqual:self.mediaSourceURL]) {
        NSLog(@"new target so stopping...");
        [self stopWithBlock:^() {
            NSLog(@"restarting playback");
            self.mediaSourceURL = url;
            playing = YES;
            [self startDownload];
        }];
    }
    
}

-(NSURL *)selectPickedResolutionURL
{
    OGVPlaybackResolution index = (OGVPlaybackResolution)self.resolutionPicker.selectedSegmentIndex;
    switch (index) {
        case OGVPlaybackResolution160p:
            return [self.mediaSource derivativeURLForHeight:160];
        case OGVPlaybackResolution360p:
            return [self.mediaSource derivativeURLForHeight:360];
        case OGVPlaybackResolution480p:
            return [self.mediaSource derivativeURLForHeight:480];
        case OGVPlaybackResolutionOrig:
            return self.mediaSource.sourceURL;
        default:
            NSLog(@"noooooooooooooooooooo unknown resolution");
            return nil;
    }
}

@end
