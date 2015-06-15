//
//  OGVPlayerState.m
//  Pods
//
//  Created by Brion on 6/13/15.
//
//

#import <OGVKit/OGVKit.h>

@implementation OGVPlayerState
{
    __weak id<OGVPlayerStateDelegate> delegate;

    NSURLConnection *connection;
    OGVAudioFeeder *audioFeeder;
    OGVDecoder *decoder;

    NSMutableArray *inputDataQueue;

    float frameEndTimestamp;
    
    BOOL doneDownloading;
    BOOL waitingForData;
    BOOL playing;
    
    dispatch_queue_t decodeQueue;
    dispatch_queue_t drawingQueue;
}

#pragma mark - Public methods

-(instancetype)initWithURL:(NSURL *)URL delegate:(id<OGVPlayerStateDelegate>)aDelegate
{
    assert(URL);
    self = [super init];
    if (self) {
        delegate = aDelegate;

        decoder = [[OGVDecoder alloc] init];
        
        // decode on background thread
        decodeQueue = dispatch_queue_create("OGVKit.Decoder", NULL);
        
        // draw on UI thread
        drawingQueue = dispatch_get_main_queue();
        
        [self startDownload:URL];
    }
    return self;
}

-(void)play
{
    dispatch_async(decodeQueue, ^() {
        if (decoder.dataReady) {
            if (playing) {
                playing = NO;
            } else {
                playing = YES;
                // @todo start audio etc
                [self pingProcessing:0];
            }
        } else {
            // @todo maybe set us up to play once loading is ready
        }
    });
}

-(void)pause
{
    dispatch_async(decodeQueue, ^() {
        playing = NO;
        // @todo stop audio etc
    });
}

-(void)cancel
{
    dispatch_async(decodeQueue, ^() {
        if (playing) {
            playing = NO;
        }

        if (connection) {
            [connection cancel];
        }
        connection = nil;

        if (audioFeeder) {
            [audioFeeder close];
        }
        audioFeeder = nil;

        decoder = nil;
    });
}

-(BOOL)playing
{
    return playing;
}

#pragma mark - Private methods on main thread

- (void)startDownload:(NSURL *)sourceURL
{
    NSURLRequest *req = [NSURLRequest requestWithURL:sourceURL];
    connection = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:NO];
    [connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [connection start];
    
    playing = YES;
    doneDownloading = NO;
    waitingForData = YES;
    inputDataQueue = [[NSMutableArray alloc] init];
}

#pragma mark - Private decode thread methods

- (void)initPlaybackState
{
    assert(decoder.dataReady);
    
    frameEndTimestamp = 0.0f;
    
    if (decoder.hasAudio) {
        audioFeeder = [[OGVAudioFeeder alloc] initWithSampleRate:decoder.audioRate
                                                        channels:decoder.audioChannels];
    }
    
    dispatch_async(drawingQueue, ^() {
        if ([delegate respondsToSelector:@selector(ogvPlayerStateDidLoadMetadata:)]) {
            [delegate ogvPlayerStateDidLoadMetadata:self];
        }
        if ([delegate respondsToSelector:@selector(ogvPlayerStateDidPlay:)]) {
            [delegate ogvPlayerStateDidPlay:self];
        }
    });
}

- (void)processNextFrame
{
    if (!playing) {
        return;
    }
    BOOL more;
    
    while (true) {
        BOOL wasDataReady = decoder.dataReady;

        more = [decoder process];
        if (!more) {
            // Decoder wants more data

            if ([inputDataQueue count] > 0) {
                NSData *inputData = inputDataQueue[0];
                [inputDataQueue removeObjectAtIndex:0];
                [decoder receiveInput:inputData];

                // Try again and see if we get packets out!
                continue;
            } else {
                if (doneDownloading) {
                    // Wait for audio to run out, then close up shop!
                    float timeLeft = [audioFeeder secondsQueued];
                    dispatch_time_t closeTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeLeft * NSEC_PER_SEC));
                    dispatch_after(closeTime, drawingQueue, ^{
                        [self cancel];
                        if ([delegate respondsToSelector:@selector(ogvPlayerStateDidEnd:)]) {
                            [delegate ogvPlayerStateDidEnd:self];
                        }
                    });
                } else {
                    // Ran out of buffered input
                    // Wait for more bytes
                    waitingForData = YES;
                }

                // End the processing loop and wait for next ping.
                return;
            }
        }
        
        if (!wasDataReady) {
            if (decoder.dataReady) {
                // We flipped over to get data; set up audio etc!
                [self initPlaybackState];
            } else {
                // Still processing header data...
                continue;
            }
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
                    
                    // End the processing loop, we'll ping again after drawing
                    return;
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
            // @fixme replace this with the audio code-path using an alternate clock provider?
            BOOL readyForFrame = YES; // check time?

            if (readyForFrame && decoder.frameReady) {
                // it's time to draw
                BOOL ok = [decoder decodeFrame];
                if (ok) {
                    [self drawFrame];
                    // end the processing loop, we'll continue after drawing the frame
                } else {
                    NSLog(@"Bad video packet or something");
                    [self pingProcessing:(1.0f / decoder.frameRate)];
                }
            } else {
                // Need more processing; continue the loop
                continue;
            }
            
            // End the processing loop and wait for next ping.
            return;
        }
    }
}

- (void)pingProcessing:(float)delay
{
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC));
    dispatch_after(popTime, decodeQueue, ^() {
        [self processNextFrame];
    });
}

#pragma mark - Drawing thread methods

/**
 * Schedule a frame draw on the main thread, then return to the decoder
 * when it's done drawing.
 */
-(void)drawFrame
{
    OGVFrameBuffer *buffer = [decoder frameBuffer];
    frameEndTimestamp = buffer.timestamp;
    dispatch_async(drawingQueue, ^() {
        [delegate ogvPlayerState:self drawFrame:buffer];
        [self pingProcessing:0];
    });
}

#pragma mark NSURLConnectionDataDelegate methods

- (void)connection:(NSURLConnection *)sender didReceiveData:(NSData *)data
{
    dispatch_async(decodeQueue, ^() {
        if (sender != connection) {
            // from a previous session! discard.
            return;
        }
        
        // @todo save to temporary disk storage instead of buffering to memory!

        [inputDataQueue addObject:data];
        if (waitingForData) {
            waitingForData = NO;
            [self processNextFrame];
        }
    });
}

- (void)connectionDidFinishLoading:(NSURLConnection *)sender
{
    dispatch_async(decodeQueue, ^() {
        if (sender == connection) {
            NSLog(@"done downloading");
            doneDownloading = YES;
            waitingForData = NO;
            connection = nil;
        }
    });
}

@end
