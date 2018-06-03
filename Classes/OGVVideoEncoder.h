//
//  OGVVideoEncoder.h
//  OGVKit
//
//  Copyright (c) 2016 Brion Vibber. All rights reserved.
//

extern const NSString *OGVVideoEncoderOptionsBitrateKey;
extern const NSString *OGVVideoEncoderOptionsKeyframeIntervalKey;
extern const NSString *OGVVideoEncoderOptionsRealtimeKey;
extern const NSString *OGVVideoEncoderOptionsSpeedKey;

@interface OGVVideoEncoder : NSObject

@property (readonly) NSString *codec;
@property (readonly) OGVVideoFormat *format;
@property (readonly) NSDictionary *options;
@property (readonly) OGVQueue *packets;
@property (readonly) NSArray *headers;

-(instancetype)initWithFormat:(OGVVideoFormat *)format
                      options:(NSDictionary *)options;

-(void)encodeFrame:(OGVVideoBuffer *)buffer;

-(void)close;

@end
