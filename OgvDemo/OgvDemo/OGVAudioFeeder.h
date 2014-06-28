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

-(id)initWithSampleRate:(int)sampleRate channels:(int)channels;

-(void)bufferData:(OGVAudioBuffer *)buffer;
-(void)close;

-(int)samplesQueued;
-(float)secondsQueued;
-(float)playbackPosition;

@end
