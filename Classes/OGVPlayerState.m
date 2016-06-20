//
//  OGVPlayerState.m
//  OGVKit
//
//  Created by Brion on 6/13/15.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//
//

#import "OGVKit.h"

@interface OGVPlayerState ()
@property (readonly) float baseTime;
@end

@implementation OGVPlayerState
{
    __weak id<OGVPlayerStateDelegate> delegate;

    OGVInputStream *stream;
    OGVAudioFeeder *audioFeeder;
    OGVDecoder *decoder;

    float frameEndTimestamp;
    float initialAudioTimestamp;
    float audioPausePosition;
    CFTimeInterval initTime;
    CFTimeInterval offsetTime;

    BOOL playing;
    BOOL playAfterLoad;
    BOOL seeking;
    
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

        initTime = 0;
        offsetTime = 0;
        playing = NO;
        seeking = NO;
        playAfterLoad = NO;

        frameEndTimestamp = 0;
        initialAudioTimestamp = 0;
        audioPausePosition = 0;

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
            [self startPlayback:decoder.hasAudio ? initialAudioTimestamp : frameEndTimestamp];
        } else {
            playAfterLoad = YES;
        }
    });
}

-(void)pause
{
    dispatch_async(decodeQueue, ^() {
        offsetTime = self.playbackPosition;

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
    if (seeking) {
        // this feels very hacky!
        [decoder.inputStream cancel];
        [decoder.inputStream restart];
    }
    dispatch_async(decodeQueue, ^() {
        if (decoder && decoder.seekable) {
            BOOL wasPlaying = !self.paused;
            if (wasPlaying) {
                [self pause];
            }
            dispatch_async(decodeQueue, ^() {
                // Adjust the offset for the seek
                offsetTime += (time - frameEndTimestamp);

                BOOL ok = [decoder seek:time];

                if (ok) {
                    // Find out the actual time we seeked to!
                    // We may have gone to a keyframe nearby.
                    [self syncAfterSeek:time exact:YES];
                    frameEndTimestamp = decoder.frameTimestamp;
                    initialAudioTimestamp = decoder.audioTimestamp;

                    dispatch_async(drawingQueue, ^() {
                        if ([delegate respondsToSelector:@selector(ogvPlayerStateDidSeek:)]) {
                            [delegate ogvPlayerStateDidSeek:self];
                        }
                    });
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
    double position = 0.0;
    if (playing) {
        position = self.baseTime - initTime + offsetTime;
    } else {
        position = offsetTime - initTime;
    }
    
    return (position > 0.0) ? position : 0.0;
}

- (float)baseTime
{
    if (decoder.hasAudio) {
        if (audioFeeder) {
            return audioFeeder.playbackPosition;
        } else {
            return audioPausePosition;
        }
    } else {
        return CACurrentMediaTime();
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

- (void)startPlayback:(float)offset
{
    assert(decoder.dataReady);
    assert(offset >= 0);

    playing = YES;
    if (decoder.hasAudio) {
        [self startAudio];
    }
    
    [self initPlaybackState:offset];

    dispatch_async(drawingQueue, ^() {
        if ([delegate respondsToSelector:@selector(ogvPlayerStateDidPlay:)]) {
            [delegate ogvPlayerStateDidPlay:self];
        }
    });
    [self pingProcessing:0];
}

- (void)initPlaybackState:(float)offset
{
    assert(decoder.dataReady);
    assert(offset >= 0);
    
    frameEndTimestamp = 0.0f;
    initTime = self.baseTime;
    offsetTime = offset;
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
    audioPausePosition = audioFeeder.playbackPosition;
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
                [self startPlayback:0];
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
    BOOL more;
    
    while (true) {
        more = [decoder process];
        if (!more) {
            if (decoder.inputStream.state == OGVInputStreamStateFailed) {
                NSLog(@"Hey! The input stream failed. Handle this more gracefully.");
                [self pause];
                return;
            }
            
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

        float nextDelay = INFINITY;
        const float fudgeDelta = 0.1f;
        float playbackPosition = self.playbackPosition;
        float frameDelay = (frameEndTimestamp - playbackPosition);
        
        // See if the frame timestamp is behind the playhead
        BOOL readyToDecodeFrame = (frameDelay <= 0.0);
        BOOL readyToDrawFrame = (fabsf(frameDelay) <= fudgeDelta);
        
        if (decoder.hasAudio) {
            // Drive on the audio clock!
            const int bufferSize = 8192;
            const float bufferDuration = (float)bufferSize / decoder.audioFormat.sampleRate;
            
            float audioBufferedDuration = [audioFeeder secondsQueued];
            BOOL readyForAudio = (audioBufferedDuration <= bufferDuration * 4) || ![audioFeeder isStarted];
            
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
            
            if (audioBufferedDuration <= bufferDuration) {
                // NEED MOAR BUFFERS
                nextDelay = 0;
            } else {
                // Check in when the audio buffer runs low again...
                nextDelay = fminf(nextDelay, bufferDuration / 4.0f);
                // @todo revisit this checkin frequency, it's pretty made up
            }
        }
        
        if (readyToDecodeFrame && decoder.frameReady) {
            //NSLog(@"%f ms frame delay", frameDelay * 1000);
            BOOL ok = [decoder decodeFrame];
            if (ok) {
                // Check if it's time to draw (AKA the frame timestamp is at or past the playhead)
                if (readyToDrawFrame) {
                    // If we're already playing, DRAW!
                    [self drawFrame];
                    
                    // End the processing loop, we'll ping again after drawing
                    return;
                } else {
                    // Not ready to draw yet, update the timestamp and keep on chuggin
                    OGVVideoBuffer *buffer = [decoder frameBuffer];
                    frameEndTimestamp = buffer.timestamp;
                    continue;
                }
            } else {
                NSLog(@"Bad video packet or something");
                [self pingProcessing:(1.0f / 30)];
            }
        } else if (!playing) {
            // We're all caught up but paused, will be pinged when played
            return;
        } else {
            // Need more processing; continue the loop
            continue;
        }
        
        if (nextDelay < INFINITY) {
            [self pingProcessing:nextDelay];
            
            // End the processing loop and wait for next ping.
            return;
        } else {
            // Continue the processing loop...
            continue;
        }
        
        // End the processing loop and wait for next ping.
        return;
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
        if (decoder) {
            [delegate ogvPlayerState:self drawFrame:buffer];
            [self pingProcessing:0];
        }
    });
}

-(BOOL)syncAfterSeek:(float)target exact:(BOOL)exact
{
    while ((decoder.hasAudio && !decoder.audioReady) || (decoder.hasVideo && !decoder.frameReady)) {
        if (![decoder process]) {
            NSLog(@"Got to end of file before found data again after seek.");
            break;
        }
    }
    while (YES) {
        if (![decoder process]) {
            NSLog(@"Got to end of file before found data again after seek.");
            break;
        }
        if (exact) {
            if (decoder.hasAudio && decoder.audioReady && decoder.audioTimestamp < target) {
                [decoder decodeAudio];
            }
            if (decoder.hasVideo && decoder.frameReady && decoder.frameTimestamp < target) {
                [decoder decodeFrame];
            }
            if ((!decoder.hasVideo || decoder.frameTimestamp >= target) &&
                (!decoder.hasAudio || decoder.audioTimestamp >= target)) {
                break;
            }
        } else {
            // We're ok leaving off after the keyframe
            break;
        }
    }

    if (decoder.hasVideo) {
        // Show where we left off
        BOOL ok = [decoder decodeFrame];
        if (ok) {
            [self drawFrame];
        }
        return ok;
    } else {
        // If audio-only there's nothing to do after seeking.
        return YES;
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
            // Break the stream off from us and send it to the decoder.
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

-(void)OGVInputStream:(OGVInputStream *)sender customizeURLRequest:(NSMutableURLRequest *)request
{
    if ([delegate respondsToSelector:@selector(ogvPlayerState:customizeURLRequest:)]) {
        [delegate ogvPlayerState:self customizeURLRequest:request];
    }
}

@end
