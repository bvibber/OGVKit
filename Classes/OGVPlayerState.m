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

    OGVStreamFile *stream;
    OGVAudioFeeder *audioFeeder;
    OGVDecoder *decoder;

    float frameEndTimestamp;
    float initialAudioTimestamp;
    
    BOOL playing;
    BOOL playAfterLoad;
    
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

        // decode on background thread
        decodeQueue = dispatch_queue_create("OGVKit.Decoder", NULL);

        // draw on UI thread
        drawingQueue = dispatch_get_main_queue();

        stream = [[OGVStreamFile alloc] initWithURL:URL];
        decoder = [[OGVDecoder alloc] init];
        decoder.inputStream = stream;

        playing = NO;
        playAfterLoad = NO;

        // Start loading the URL and processing header data
        dispatch_async(decodeQueue, ^() {
            [stream start];
            [self processHeaders];
        });
    }
    return self;
}

-(void)play
{
    dispatch_async(decodeQueue, ^() {
        if (playing) {
            // Already playing
        } else if (decoder.dataReady) {
            [self startPlayback];
        } else {
            playAfterLoad = YES;
        }
    });
}

-(void)pause
{
    dispatch_async(decodeQueue, ^() {
        if (audioFeeder) {
            [self stopAudio];
        }

        if (playing) {
            playing = NO;
            dispatch_async(drawingQueue, ^() {
                if ([delegate respondsToSelector:@selector(ogvPlayerStateDidPause:)]) {
                    [delegate ogvPlayerStateDidPause:self];
                }
            });
        }
    });
}

-(void)cancel
{
    [self pause];

    dispatch_async(decodeQueue, ^() {
        if (stream) {
            [stream cancel];
        }
        stream = nil;
        decoder = nil;
    });
}

-(BOOL)paused
{
    return !playing;
}

-(float)playbackPosition
{
    // @todo use alternate clock provider for video-only files
    if (playing) {
        return audioFeeder.playbackPosition + initialAudioTimestamp;
    } else {
        return initialAudioTimestamp;
    }
}

#pragma mark - Private decode thread methods

- (void)startPlayback
{
    playing = YES;
    if (decoder.hasAudio) {
        [self startAudio];
    }
    [self initPlaybackState];
    dispatch_async(drawingQueue, ^() {
        if ([delegate respondsToSelector:@selector(ogvPlayerStateDidPlay:)]) {
            [delegate ogvPlayerStateDidPlay:self];
        }
    });
    [self pingProcessing:0];
}

- (void)initPlaybackState
{
    assert(decoder.dataReady);
    
    frameEndTimestamp = 0.0f;
    
    if (decoder.hasAudio) {
        [self startAudio];
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

-(void)startAudio
{
    assert(decoder.hasAudio);
    assert(!audioFeeder);
    audioFeeder = [[OGVAudioFeeder alloc] initWithSampleRate:decoder.audioRate
                                                    channels:decoder.audioChannels];
    //NSLog(@"start: %f", initialAudioTimestamp);
}

-(void)stopAudio
{
    assert(decoder.hasAudio);
    assert(audioFeeder);
    initialAudioTimestamp = initialAudioTimestamp + audioFeeder.bufferTailPosition;
    // @fixme let the already-queued audio play out when pausing?
    [audioFeeder close];
    audioFeeder = nil;
}

- (void)processHeaders
{
    BOOL ok = [decoder process];
    if (ok) {
        if (decoder.dataReady) {
            if (playAfterLoad) {
                playAfterLoad = NO;
                [self startPlayback];
            }
        } else {
            dispatch_async(decodeQueue, ^() {
                [self processHeaders];
            });
        }
    } else {
        NSLog(@"Error processing header state. :(");
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
            // Wait for audio to run out, then close up shop!
            float timeLeft;
            if (audioFeeder) {
                timeLeft = [audioFeeder secondsQueued];
            } else {
                timeLeft = 0;
            }

            dispatch_time_t closeTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeLeft * NSEC_PER_SEC));
            dispatch_after(closeTime, drawingQueue, ^{
                [self cancel];
                if ([delegate respondsToSelector:@selector(ogvPlayerStateDidPause:)]) {
                    [delegate ogvPlayerStateDidPause:self];
                }
                if ([delegate respondsToSelector:@selector(ogvPlayerStateDidEnd:)]) {
                    [delegate ogvPlayerStateDidEnd:self];
                }
            });

            return;
        }

        if (decoder.hasAudio) {
            // Drive on the audio clock!
            const float fudgeDelta = 0.001f;
            const int bufferSize = 8192;
            const float bufferDuration = (float)bufferSize / (float)decoder.audioRate;
            
            float audioBufferedDuration = [audioFeeder secondsQueued];
            BOOL readyForAudio = (audioBufferedDuration <= bufferDuration) || ![audioFeeder isStarted];
            
            float frameDelay = (frameEndTimestamp - self.playbackPosition);
            BOOL readyForFrame = (frameDelay <= fudgeDelta);
            
            if (readyForAudio && decoder.audioReady) {
                //NSLog(@"%f ms audio queued; buffering", audioBufferedDuration * 1000);
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
                //NSLog(@"%f ms frame delay", frameDelay * 1000);
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
            if (decoder.hasAudio) {
                if (audioBufferedDuration <= bufferDuration * 2) {
                    // NEED MOAR BUFFERS
                    [nextDelays addObject:@0];
                } else {
                    // Check in when the audio buffer runs low again...
                    [nextDelays addObject:@(bufferDuration / 2.0f)];
                }
            }
            if (decoder.hasVideo) {
                // Check in when the next frame is due
                // todo: Subtract time we already spent decoding
                [nextDelays addObject:@(frameDelay)];
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

/**
 * Schedule a frame draw on the main thread, then return to the decoder
 * when it's done drawing.
 */
-(void)drawFrame
{
    OGVFrameBuffer *buffer = [decoder frameBuffer];
    frameEndTimestamp = buffer.timestamp;
    //NSLog(@"frame: %f %f", frameEndTimestamp, self.playbackPosition);
    dispatch_async(drawingQueue, ^() {
        [delegate ogvPlayerState:self drawFrame:buffer];
        [self pingProcessing:0];
    });
}

/*
#pragma mark - OGVStreamFileDelegate methods
- (void)ogvStreamFileDataAvailable:(OGVStreamFile *)sender
{
    dispatch_async(decodeQueue, ^() {
        [self processNextFrame];
    });
}
*/

@end
