//
//  OGVPacket.h
//  OGVKit
//
//  Copyright (c) 2016 Brion Vibber. All rights reserved.
//

@interface OGVPacket : NSObject

@property NSData *data;
@property float timestamp;
@property float duration;

-(instancetype)initWithData:(NSData *)data timestamp:(float)timestamp duration:(float)duration;

@end
