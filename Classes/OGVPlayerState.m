//
//  OGVPlayerState.m
//  OGVKit
//
//  Created by Brion on 6/13/15.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//
//

#import "OGVKit.h"

@implementation OGVPlayerState
{
    __weak id<OGVPlayerStateDelegate> delegate;

    OGVInputStream *stream;
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

        stream = [[OGVInputStream alloc] initWithURL:URL];

        playing = NO;
        playAfterLoad = NO;

        // Start loading the URL and processing header data
        dispatch_async(decodeQueue, ^() {
            // @todo set our own state to connecting!
            stream.delegate = self;
            [stream start];
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

-(void)seek:(float)time
{
    dispatch_async(decodeQueue, ^() {
        if (decoder && decoder.seekable) {
            BOOL wasPlaying = !self.paused;
            if (wasPlaying) {
                [self pause];
            }
            dispatch_async(decodeQueue, ^() {
                frameEndTimestamp = time;
                initialAudioTimestamp = time;

                BOOL ok = [decoder seek:time];

                if (ok) {
                    float ts = [self timestampAfterSeek];
                    //NSLog(@"%f, was %f / %f", ts, frameEndTimestamp, initialAudioTimestamp);

                    frameEndTimestamp = ts;
                    initialAudioTimestamp = ts;
                    if (wasPlaying) {
                        [self play];
                    }
                }
            });
        }
    });
}


#pragma mark - getters/setters

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

-(float)duration
{
    if (decoder) {
        return decoder.duration;
    } else {
        return INFINITY;
    }
}

-(BOOL)seekable
{
    if (decoder) {
        return decoder.seekable;
    } else {
        return NO;
    }
}

#pragma mark - Private decode thread methods

- (void)startDecoder
{
    decoder = [[OGVKit singleton] decoderForType:stream.mediaType];
    if (decoder) {
        // Hand the stream off to the decoder and goooooo!
        decoder.inputStream = stream;
        [self processHeaders];
    } else {
        NSLog(@"no decoder, this should not happen");
        abort();
    }
    // @fixme update our state
}

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
    
    dispatch_async(drawingQueue, ^() {
        if ([delegate respondsToSelector:@selector(ogvPlayerStateDidPlay:)]) {
            [delegate ogvPlayerStateDidPlay:self];
        }
    });
}

-(void)startAudio
{
    assert(decoder.hasAudio);
    assert(!audioFeeder);
    audioFeeder = [[OGVAudioFeeder alloc] initWithFormat:decoder.audioFormat];
    NSLog(@"start: %f", initialAudioTimestamp);
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
            if ([delegate respondsToSelector:@selector(ogvPlayerStateDidLoadMetadata:)]) {
                [delegate ogvPlayerStateDidLoadMetadata:self];
            }
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
            const float bufferDuration = (float)bufferSize / decoder.audioFormat.sampleRate;
            
            float audioBufferedDuration = [audioFeeder secondsQueued];
            BOOL readyForAudio = (audioBufferedDuration <= bufferDuration * 4) || ![audioFeeder isStarted];
            
            float playbackPosition = self.playbackPosition;
            float frameDelay = (frameEndTimestamp - playbackPosition);
            //NSLog(@"%f = %f - %f", frameDelay, frameEndTimestamp, playbackPosition);
            
            BOOL readyForFrame = (frameDelay <= fudgeDelta);
            
            //NSLog(@"%d %d / %d %d (%f - %f)", readyForAudio, decoder.audioReady, readyForFrame, decoder.frameReady, frameEndTimestamp, playbackPosition);
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
            
            float nextDelay = INFINITY;
            if (decoder.hasAudio) {
                if (audioBufferedDuration <= bufferDuration) {
                    // NEED MOAR BUFFERS
                    nextDelay = 0;
                } else {
                    // Check in when the audio buffer runs low again...
                    nextDelay = fminf(nextDelay, bufferDuration / 2.0f);
                }
            }
            if (decoder.hasVideo) {
                // Check in when the next frame is due
                // todo: Subtract time we already spent decoding
                // todo: remove that / 2 hack
                nextDelay = fminf(nextDelay, frameDelay / 2);
            }
            
            if (nextDelay < INFINITY) {
                [self pingProcessing:nextDelay];
                
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
                    // @todo finish replacing this path! we no longer record a frame rate
                    [self pingProcessing:(1.0f / 30)];
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
    //NSLog(@"after %f ms", delay * 1000);
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
    OGVVideoBuffer *buffer = [decoder frameBuffer];
    frameEndTimestamp = buffer.timestamp;
    //NSLog(@"frame: %f %f", frameEndTimestamp, self.playbackPosition);
    dispatch_async(drawingQueue, ^() {
        [delegate ogvPlayerState:self drawFrame:buffer];
        [self pingProcessing:0];
    });
}

-(float)timestampAfterSeek
{
    while (true) {
        if (decoder.hasAudio) {
            if (decoder.audioReady) {
                float ts = decoder.audioTimestamp;
                if (ts < 0) {
                    NSLog(@"decoder.audioTimestamp invalid or unimplemented in post-seek sync");
                    return initialAudioTimestamp;
                } else {
                    return ts;
                }
            }
        } else if (decoder.hasVideo) {
            if (decoder.frameReady) {
                float ts = decoder.frameTimestamp;
                if (ts < 0) {
                    NSLog(@"decoder.frameTimestamp invalid or unimplemented in post-seek sync");
                    return initialAudioTimestamp;
                } else {
                    return ts;
                }
            }
        } else {
            NSLog(@"Got to end of file before resynced timestamps.");
            return initialAudioTimestamp;
        }
        if (![decoder process]) {
            NSLog(@"Got to end of file before found timestamps again after seek.");
            return initialAudioTimestamp;
        }
    }
}

#pragma mark - OGVInputStreamDelegate methods

-(void)OGVInputStreamStateChanged:(OGVInputStream *)sender
{
    switch (stream.state) {
        case OGVInputStreamStateConnecting:
            // Good... Good. Let the data flow through you!
            break;

        case OGVInputStreamStateReading:
            stream.delegate = nil;
            [self startDecoder];
            break;

        case OGVInputStreamStateFailed:
            NSLog(@"Stream file failed.");
            stream.delegate = nil;
            [stream cancel];
            stream = nil;
            break;

        case OGVInputStreamStateCanceled:
            // we canceled it, eh
            break;

        default:
            NSLog(@"Unexpected stream state change! %d", (int)stream.state);
            stream.delegate = nil;
            [stream cancel];
            stream = nil;
    }
}

@end
