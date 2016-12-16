//
//  OGVAudioFeeder.h
//  OGVKit
//
//  Created by Brion on 6/28/14.
//  Copyright (c) 2014-2015 Brion Vibber. All rights reserved.
//

@interface OGVAudioFeeder : NSObject

@property (readonly) OGVAudioFormat *format;

/**
 * Initializer!
 */
-(id)initWithFormat:(OGVAudioFormat *)format;


/**
 * Queue up a chunk of audio for future output.
 *
 * Audio will start automatically once enough buffers have been queued.
 */
-(void)bufferData:(OGVAudioBuffer *)buffer;

/**
 * Close this audio channel.
 */
-(void)close;

/**
 * Amount of audio queued up and not yet played, in samples
 */
-(int)samplesQueued;

/**
 * Amount of audio queued up and not yet played, in seconds
 */
-(float)secondsQueued;

/**
 * Get current playback position, in seconds (maybe)
 */
-(float)playbackPosition;

/**
 * Get amount of time before the current playback & queue run out, in seconds
 */
-(float)timeAwaitingPlayback;

/**
 * Get the future playback position at which current audio will run out
 */
@property (readonly) float bufferTailPosition;

/**
 * Have we started?
 */
-(BOOL)isStarted;

/**
 * Are we closing out after end?
 */
-(BOOL)isClosing;

/**
 * Are we closed?
 */
-(BOOL)isClosed;

@end
