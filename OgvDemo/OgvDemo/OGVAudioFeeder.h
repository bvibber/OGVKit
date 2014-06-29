//
//  OGVAudioFeeder.h
//  OgvDemo
//
//  Created by Brion on 6/28/14.
//  Copyright (c) 2014 Brion Vibber. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OgvKit/OgvKit.h>

@interface OGVAudioFeeder : NSObject

@property (readonly) int sampleRate;
@property (readonly) int channels;

/**
 * Initializer!
 */
-(id)initWithSampleRate:(int)sampleRate channels:(int)channels;


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

@end
