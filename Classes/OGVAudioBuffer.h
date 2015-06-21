//
//  OGVAudioBuffer.h
//  OgvDemo
//
//  Created by Brion on 11/5/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

@interface OGVAudioBuffer : NSObject

@property (readonly) OGVAudioFormat *format;
@property (readonly) unsigned int samples;

- (id)initWithPCM:(float **)pcm samples:(unsigned int)samples format:(OGVAudioFormat *)format;
- (const float *)PCMForChannel:(unsigned int)channel;

@end
