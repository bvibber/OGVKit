//
//  OGVPacket.h
//  OGVKit
//
//  Copyright (c) 2016 Brion Vibber. All rights reserved.
//

@interface OGVPacket : NSObject

@property NSData *data;
@property float timestamp;

-(instancetype)initWithData:(NSData *)data timestamp:(float)timestamp;
+(OGVPacket *)packetWithData:(NSData *)data timestamp:(float)timestamp;

@end
