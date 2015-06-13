//
//  OGVPlayerState.m
//  Pods
//
//  Created by Brion on 6/13/15.
//
//

#import <OGVKit/OGVKit.h>
#import "OGVPlayerState.h"

@implementation OGVPlayerState
{
    __weak OGVPlayerView *_playerView;

    NSURLConnection *connection;
    OGVAudioFeeder *audioFeeder;
    OGVDecoder *decoder;
    
    float frameEndTimestamp;
    
    BOOL doneDownloading;
    BOOL waitingForData;
    BOOL playing;
    
    dispatch_queue_t decodeQueue;
    dispatch_queue_t drawingQueue;
}

#pragma mark - Public methods

-(instancetype)initWithPlayerView:(OGVPlayerView *)playerView
{
    self = [super init];
    if (self) {
        _playerView = playerView;

        decoder = [[OGVDecoder alloc] init];
        
        // decode on background thread
        decodeQueue = dispatch_queue_create("Decoder", NULL);
        
        // draw on UI thread
        drawingQueue = dispatch_get_main_queue();
        
        [self startDownload:playerView.sourceURL];
    }
    return self;
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


#pragma mark - Private methods

- (void)startDownload:(NSURL *)sourceURL
{
    NSURLRequest *req = [NSURLRequest requestWithURL:sourceURL];
    connection = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:NO];
    [connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [connection start];
    
    playing = YES;
    doneDownloading = NO;
    waitingForData = YES;
}

#pragma mark - Decode thread methods

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
        more = [decoder process];
        if (!more) {
            if (doneDownloading) {
                // @todo wait for audio to run out!
                float timeLeft = [audioFeeder secondsQueued];
                NSLog(@"out of data, closing in %f ms", timeLeft * 1000.0f);
                dispatch_time_t closeTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeLeft * NSEC_PER_SEC));
                dispatch_after(closeTime, drawingQueue, ^{
                    [self stop];
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
        
        if (!decoder.dataReady) {
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
        [_playerView.frameView drawFrame:buffer];
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
