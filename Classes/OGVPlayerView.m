//
//  OGVPlayerView.m
//  OgvKit
//
//  Created by Brion on 2/8/15.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import <OgvKit/OgvKit.h>

@implementation OGVPlayerView

{
    OGVDecoder *decoder;
    NSURLConnection *connection;
    
    BOOL doneDownloading;
    BOOL waitingForData;
    BOOL playing;
    
    dispatch_queue_t decodeQueue;
    dispatch_queue_t drawingQueue;
    
    OGVAudioFeeder *audioFeeder;
    float frameEndTimestamp;
    
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

-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        OGVFrameView *frameView = [[OGVFrameView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        [self addSubview:frameView];
        self.frameView = frameView;
    }
    return self;
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        OGVFrameView *frameView = [[OGVFrameView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
        [self addSubview:frameView];
        self.frameView = frameView;
    }
    return self;
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    self.frameView.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
}

-(void)play
{
    [self startDownload];
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
        playing = NO;
        
        if (!doneDownloading) {
            [connection cancel];
        }
        
        dispatch_async(decodeQueue, ^() {
            decoder = nil;
            dispatch_async(dispatch_get_main_queue(), ^() {
                connection = nil;
                
                [audioFeeder close];
                audioFeeder = nil;
                
                completionBlock();
            });
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), completionBlock);
    }
}


- (void)processNextFrame
{
    if (!playing) {
        return;
    }
    BOOL more;
    
    while (true) {
        more = [decoder process];
        if (!more) {
            if (doneDownloading) {
                // @todo wait for audio to run out!
                float timeLeft = [audioFeeder secondsQueued];
                NSLog(@"out of data, closing in %f ms", timeLeft * 1000.0f);
                dispatch_time_t closeTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeLeft * NSEC_PER_SEC));
                dispatch_after(closeTime, drawingQueue, ^{
                    [self stopWithBlock:^{}];
                });
            } else {
                // Ran out of buffered input
                // Wait for more bytes
                waitingForData = YES;
            }
            // End the processing loop and wait for next ping.
            return;
        }
        
        if (!(decoder.audioReady || decoder.frameReady)) {
            // Have to process some more pages to find data. Continue the loop.
            continue;
        }
        
        if (decoder.hasAudio) {
            // Drive on the audio clock!
            const float fudgeDelta = 0.001f;
            const int bufferSize = 8192;
            const float bufferDuration = (float)bufferSize / (float)decoder.audioRate;
            
            float audioBufferedDuration = [audioFeeder secondsQueued];
            //NSLog(@"%f ms audio queued", audioBufferedDuration * 1000);
            BOOL readyForAudio = (audioBufferedDuration <= bufferDuration * 2) || ![audioFeeder isStarted];
            
            float frameDelay = (frameEndTimestamp - [audioFeeder playbackPosition]);
            BOOL readyForFrame = (frameDelay <= fudgeDelta);
            
            if (readyForAudio && decoder.audioReady) {
                BOOL ok = [decoder decodeAudio];
                if (ok) {
                    //NSLog(@"Buffering audio...");
                    OGVAudioBuffer *audioBuffer = [decoder audioBuffer];
                    [audioFeeder bufferData:audioBuffer];
                } else {
                    NSLog(@"Bad audio packet or something");
                }
            }
            
            if (readyForFrame && decoder.frameReady) {
                BOOL ok = [decoder decodeFrame];
                if (ok) {
                    [self drawFrame];
                } else {
                    NSLog(@"Bad video packet or something");
                }
            }
            
            NSMutableArray *nextDelays = [[NSMutableArray alloc] init];
            if (audioBufferedDuration <= bufferDuration * 2) {
                // NEED MOAR BUFFERS
            } else {
                // Check in when the audio buffer runs low again...
                [nextDelays addObject:@(bufferDuration / 2.0f)];
                
                if (decoder.hasVideo) {
                    // Check in when the next frame is due
                    // todo: Subtract time we already spent decoding
                    [nextDelays addObject:@(frameDelay)];
                }
            }
            
            if ([nextDelays count]) {
                NSArray *sortedDelays = [nextDelays sortedArrayUsingSelector:@selector(compare:)];
                NSNumber *nextDelay = sortedDelays[0];
                [self pingProcessing:[nextDelay floatValue]];
                
                // End the processing loop and wait for next ping.
                return;
            } else {
                // Continue the processing loop...
                continue;
            }
        } else {
            // Drive on the video clock
            BOOL readyForFrame = YES; // check time?
            if (readyForFrame && decoder.frameReady) {
                // it's time to draw
                BOOL ok = [decoder decodeFrame];
                if (ok) {
                    [self drawFrame];
                    [self pingProcessing:(1.0f / decoder.frameRate)];
                } else {
                    NSLog(@"Bad video packet or something");
                    [self pingProcessing:(1.0f / decoder.frameRate)];
                }
            }
            
            // End the processing loop and wait for next ping.
            return;
        }
    }
}

- (void)pingProcessing:(float)delay
{
    //NSLog(@"ping after %f ms", delay * 1000.0);
    // ...
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC));
    dispatch_after(popTime, decodeQueue, ^() {
        [self processNextFrame];
    });
}

- (void)loadVideoSample
{
    if (self.sourceURL) {
        NSURLRequest *req = [NSURLRequest requestWithURL:self.sourceURL];
        connection = [NSURLConnection connectionWithRequest:req delegate:self];
        playing = YES;
        doneDownloading = NO;
        waitingForData = YES;
    } else {
        NSLog(@"Nothing to play");
    }
}

- (void)initPlaybackState
{
    assert(decoder.dataReady);
    
    // Number of pixels per second we must decode and draw to keep up
    pixelsPerFrame = decoder.frameWidth * decoder.frameHeight;
    targetPixelRate = pixelsPerFrame * decoder.frameRate;
    
    pixelsProcessed = 0;
    
    decodingTime = 0;
    averageDecodingRate = 0;
    
    drawingTime = 0;
    averageDrawingRate = 0;
    
    frameEndTimestamp = 0.0f;
    
    if (decoder.hasAudio) {
        audioFeeder = [[OGVAudioFeeder alloc] initWithSampleRate:decoder.audioRate
                                                        channels:decoder.audioChannels];
    }
}

#pragma mark Drawing methods

-(void)drawFrame
{
    OGVFrameBuffer *buffer = [decoder frameBuffer];
    [self drawBuffer:buffer];
    frameEndTimestamp = buffer.timestamp;
}

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
    /*
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
     */
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
    dispatch_async(decodeQueue, ^() {
        NSLog(@"done downloading");
        doneDownloading = YES;
        waitingForData = NO;
    });
}

@end
