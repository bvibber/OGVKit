//
//  OGVPlayerState.m
//  OGVKit
//
//  Created by Brion on 6/13/15.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//
//

#import "OGVKit.h"

#import "OGVFileInputStream.h"
#import "OGVHTTPInputStream.h"

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
    float audioPausePosition;

    CFTimeInterval initTime; // [self baseTime] at the beginning of timeline counting
    CFTimeInterval offsetTime; // offset from initTime to 'live' time at the beginning of timeline counting

    BOOL playing;
    BOOL playAfterLoad;
    BOOL seeking;
    BOOL ended;
    
    dispatch_queue_t decodeQueue;
    dispatch_queue_t delegateQueue;
}

#pragma mark - Public methods

-(instancetype)initWithURL:(NSURL *)URL
                  delegate:(id<OGVPlayerStateDelegate>)aDelegate
{
    return [self initWithInputStream:[OGVInputStream inputStreamWithURL:URL]
                            delegate:aDelegate];
}

-(instancetype)initWithInputStream:(OGVInputStream *)inputStream
                          delegate:(id<OGVPlayerStateDelegate>)aDelegate
{
    return [self initWithInputStream:inputStream
                            delegate:aDelegate
                       delegateQueue:dispatch_get_main_queue()];
}

-(instancetype)initWithInputStream:(OGVInputStream *)inputStream
                          delegate:(id<OGVPlayerStateDelegate>)aDelegate
                     delegateQueue:(dispatch_queue_t)aDelegateQueue
{
    self = [super init];
    if (self) {
        delegate = aDelegate;

        // decode on background thread
        decodeQueue = dispatch_queue_create("OGVKit.Decoder", NULL);

        // draw on UI thread
        delegateQueue = aDelegateQueue;

        stream = inputStream;
        initTime = 0;
        offsetTime = 0;
        playing = NO;
        seeking = NO;
        playAfterLoad = NO;

        frameEndTimestamp = 0;
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
        } else if (ended) {
            ended = NO;
            playing = YES;
            [self seek:0.0f];
        } else if (decoder.dataReady) {
            [self startPlayback:decoder.hasAudio ? audioPausePosition : frameEndTimestamp];
        } else {
            playAfterLoad = YES;
        }
    });
}

-(void)pause
{
    dispatch_async(decodeQueue, ^() {
        float newBaseTime = self.baseTime;
        offsetTime = self.playbackPosition;
        initTime = newBaseTime;
        if (audioFeeder) {
            [self stopAudio];
        }

        if (playing) {
            playing = NO;
            [self callDelegateSelector:@selector(ogvPlayerStateDidPause:) sync:NO withBlock:^() {
                [delegate ogvPlayerStateDidPause:self];
            }];
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
    ended = NO;
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
                BOOL ok = [decoder seek:time];

                if (ok) {
                    // Adjust the offset for the seek
                    offsetTime = time;
                    initTime = self.baseTime;

                    // Find out the actual time we seeked to!
                    // We may have gone to a keyframe nearby.
                    [self syncAfterSeek:time exact:YES];
                    if (decoder.frameReady) {
                        frameEndTimestamp = decoder.frameTimestamp;
                        offsetTime = frameEndTimestamp;
                    } else {
                        // probably at end?
                        frameEndTimestamp = time;
                    }
                    if (decoder.audioReady) {
                        audioPausePosition = decoder.audioTimestamp;
                        offsetTime = audioPausePosition;
                    } else {
                        // probably at end?
                        audioPausePosition = time;
                    }

                    [self callDelegateSelector:@selector(ogvPlayerStateDidSeek:) sync:NO withBlock:^() {
                        [delegate ogvPlayerStateDidSeek:self];
                    }];
                    if (wasPlaying) {
                        [self play];
                    } else if (decoder.hasVideo) {
                        // Show where we left off
                        if ([decoder decodeFrame]) {
                            [self drawFrame];
                        }
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
        position = offsetTime;
    }
    
    return (position > 0.0) ? position : 0.0;
}

- (float)baseTime
{
    if (decoder.hasAudio && audioFeeder) {
        return audioFeeder.playbackPosition;
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

- (void)callDelegateSelector:(SEL)selector sync:(BOOL)sync withBlock:(void(^)())block
{
    if ([delegate respondsToSelector:selector]) {
        if (delegateQueue) {
            if (sync) {
                dispatch_sync(delegateQueue, block);
            } else {
                dispatch_async(delegateQueue, block);
            }
        } else {
            block();
        }
    }
}

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

    [self initPlaybackState:offset];

    if (decoder.hasAudio) {
        [self startAudio:offset];
    }

    [self callDelegateSelector:@selector(ogvPlayerStateDidPlay:) sync:NO withBlock:^() {
        [delegate ogvPlayerStateDidPlay:self];
    }];
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

-(void)startAudio:(float)offset
{
    assert(decoder.hasAudio);
    assert(!audioFeeder);

    audioFeeder = [[OGVAudioFeeder alloc] initWithFormat:decoder.audioFormat];

    // Reset to audio clock
    initTime = self.baseTime;
    offsetTime = offset;
}

-(void)stopAudio
{
    assert(decoder.hasAudio);
    assert(audioFeeder);

    // Save the actual audio time as last offset
    audioPausePosition = [audioFeeder bufferTailPosition] - initTime + offsetTime;

    // @fixme let the already-queued audio play out when pausing?
    [audioFeeder close];
    audioFeeder = nil;

    // Reset to generic media clock
    initTime = self.baseTime;
    offsetTime = audioPausePosition;
}

- (void)processHeaders
{
    BOOL ok = [decoder process];
    if (ok) {
        if (decoder.dataReady) {
            [self callDelegateSelector:@selector(ogvPlayerStateDidLoadMetadata:) sync:NO withBlock:^() {
                [delegate ogvPlayerStateDidLoadMetadata:self];
            }];
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
    if (!playing) {
        return;
    }
    while (true) {
        more = [decoder process];
        if (!more) {
            if (decoder.inputStream.state == OGVInputStreamStateFailed) {
                NSLog(@"Hey! The input stream failed. Handle this more gracefully.");
                [self pause];
                playing = NO;
                return;
            }
            
            if ((!decoder.hasAudio || decoder.audioReady) && (!decoder.hasVideo || decoder.frameReady)) {
                // More packets already demuxed, just keep running them.
            } else {
                // Wait for audio to run out, then close up shop!
                float timeLeft;
                if (audioFeeder && [audioFeeder isStarted]) {
                    // @fixme if we haven't started and there's time left,
                    // we should trigger actual playback and pad the buffer.
                    timeLeft = [audioFeeder timeAwaitingPlayback];
                } else {
                    timeLeft = 0;
                }
                NSLog(@"ended? time left %f", timeLeft);
                if (timeLeft > 0) {
                    [self pingProcessing:timeLeft];
                } else {
                    [self pause];
                    ended = YES;
                    [self callDelegateSelector:@selector(ogvPlayerStateDidEnd:) sync:NO withBlock:^() {
                        [delegate ogvPlayerStateDidEnd:self];
                    }];
                }
                return;
            }
        }

        float nextDelay = INFINITY;
        const float fudgeDelta = 0.1f;
        float playbackPosition = self.playbackPosition;
        float frameDelay = (frameEndTimestamp - playbackPosition);
        
        // See if the frame timestamp is behind the playhead
        BOOL readyToDecodeFrame = (frameDelay <= 0.0);
        BOOL readyToDrawFrame = readyToDecodeFrame; // hack hack
        
        
        if (decoder.hasAudio) {
            
            if ([audioFeeder isClosed]) {
                // Switch to raw clock when audio is done.
                [self stopAudio];
            }

            if (decoder.audioReady) {
                // Drive on the audio clock!
                const float audioTimestamp = decoder.audioTimestamp;
                if (!audioFeeder) {
                    [self startAudio:audioTimestamp];
                }

                const int bufferSize = 8192 * 4; // fake
                const float bufferDuration = (float)bufferSize / decoder.audioFormat.sampleRate;
                
                float audioBufferedDuration = [audioFeeder secondsQueued];
                BOOL readyForAudio = (audioBufferedDuration <= bufferDuration);

                //NSLog(@"have %f ms", audioBufferedDuration * 1000);
                if (readyForAudio) {
                    BOOL ok = [decoder decodeAudio];
                    if (ok) {
                        //NSLog(@"Buffering audio...");
                        OGVAudioBuffer *audioBuffer = [decoder audioBuffer];
                        if (![audioFeeder bufferData:audioBuffer]) {
                            if ([audioFeeder isClosed]) {
                                // Audio died, perhaps due to starvation during slow decodes
                                // or something else unexpected. Close it out and we'll start
                                // up a new one.
                                NSLog(@"CLOSING OUT CLOSED AUDIO FEEDER");
                                [self stopAudio];
                                [self startAudio:audioTimestamp];
                                [audioFeeder bufferData:audioBuffer];
                            }
                        }
                        // Go back around the loop in case we need more
                        //NSLog(@"queued");
                        continue;
                    } else {
                        NSLog(@"Bad audio packet or something");
                    }
                }

                if (audioBufferedDuration <= bufferDuration) {
                    // NEED MOAR BUFFERS
                    nextDelay = 0;
                } else {
                    // Check in when the audio buffer runs low again...
                    nextDelay = fminf(nextDelay, fmaxf(audioBufferedDuration - bufferDuration / 2.0f, 0.0f));
                }
            } else {
                // Need to find some more packets
                continue;
            }
            
            /*
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
            */
        }
        
        if (decoder.hasVideo) {
            if (decoder.frameReady) {
                //NSLog(@"%f ms frame delay", frameDelay * 1000);
                if (readyToDecodeFrame) {
                    BOOL ok = [decoder decodeFrame];
                    if (ok) {
                        // Check if it's time to draw (AKA the frame timestamp is at or past the playhead)
                        // If we're already playing, DRAW!
                        //NSLog(@"DRAW");
                        [self drawFrame];

                        // End the processing loop, we'll ping again after drawing
                        //return;
                    } else {
                        NSLog(@"Bad video packet or something");
                        continue;
                    }
                }
                nextDelay = fminf(nextDelay, fmaxf(frameEndTimestamp - playbackPosition, 0.0f));
            } else if (!playing) {
                // We're all caught up but paused, will be pinged when played
                return;
            } else {
                // Need more processing; continue the loop
                continue;
            }
        }

        if (nextDelay < INFINITY) {
            //NSLog(@"loop %f ms", nextDelay * 1000.0);
            [self pingProcessing:nextDelay];
            
            // End the processing loop and wait for next ping.
            return;
        } else {
            // nothing to do?
            NSLog(@"loop drop?");
            return;
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
 * Dequeue frame and schedule a frame draw on the main thread
 */
-(void)drawFrame
{
    OGVVideoBuffer *buffer = decoder.frameBuffer;
    frameEndTimestamp = buffer.timestamp;
    //NSLog(@"frame: %f %f", frameEndTimestamp, self.playbackPosition);
    // Note: this must be sync because memory may belong to the decoder!
    [self callDelegateSelector:@selector(ogvPlayerState:drawFrame:) sync:YES withBlock:^() {
        [delegate ogvPlayerState:self drawFrame:buffer];
    }];
}

-(BOOL)syncAfterSeek:(float)target exact:(BOOL)exact
{
    while (YES) {
        while ((decoder.hasAudio && !decoder.audioReady) || (decoder.hasVideo && !decoder.frameReady)) {
            if (![decoder process]) {
                NSLog(@"Got to end of file before found data again after seek.");
                return NO;
            }
        }
        if (exact) {
            if (decoder.hasAudio && decoder.audioReady && decoder.audioTimestamp < target) {
                if ([decoder decodeAudio]) {
                    // no-op
                }
            }
            if (decoder.hasVideo && decoder.frameReady && decoder.frameTimestamp < target) {
                if ([decoder decodeFrame]) {
                    // no-op
                }
            }
            if ((!decoder.hasVideo || decoder.frameTimestamp >= target) &&
                (!decoder.hasAudio || decoder.audioTimestamp >= target)) {
                return YES;
            }
        } else {
            // We're ok leaving off after the keyframe
            return YES;
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
    [self callDelegateSelector:@selector(ogvPlayerState:customizeURLRequest:) sync:YES withBlock:^() {
        [delegate ogvPlayerState:self customizeURLRequest:request];
    }];
}

@end
