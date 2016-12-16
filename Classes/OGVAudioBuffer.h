//
//  OGVAudioBuffer.h
//  OGVKit
//
//  Created by Brion on 11/5/13.
//  Copyright (c) 2013-2015 Brion Vibber. All rights reserved.
//

@interface OGVAudioBuffer : NSObject

@property (readonly) OGVAudioFormat *format;
@property (readonly) unsigned int samples;
@property (readonly) float timestamp;

- (id)initWithPCM:(float **)pcm samples:(unsigned int)samples format:(OGVAudioFormat *)format timestamp:(float)timestamp;
- (const float *)PCMForChannel:(unsigned int)channel;

@end
