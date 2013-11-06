//
//  OGVDecoder.h
//  OgvDemo
//
//  Created by Brion on 11/2/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "OGVFrameBuffer.h"
#import "OGVAudioBuffer.h"

@interface OGVDecoder : NSObject

@property BOOL dataReady;

@property BOOL hasVideo;
@property int frameWidth;
@property int frameHeight;
@property float frameRate;
@property int pictureWidth;
@property int pictureHeight;
@property int pictureOffsetX;
@property int pictureOffsetY;
@property int hDecimation;
@property int vDecimation;

@property BOOL hasAudio;
@property int audioChannels;
@property int audioRate;

@property BOOL audioReady;
@property BOOL frameReady;

- (id)init;
- (void)receiveInput:(NSData *)data;
- (BOOL)process;
- (OGVFrameBuffer *)frameBuffer;
- (OGVAudioBuffer *)audioBuffer;


@end
