//
//  OGVAudioFormat.h
//  OGVKit
//
//  Created by Brion on 6/21/2015.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

@interface OGVAudioFormat : NSObject

@property (readonly) unsigned int channels;
@property (readonly) float sampleRate;

- (instancetype)initWithChannels:(unsigned int)channels sampleRate:(float)sampleRate;

@end
