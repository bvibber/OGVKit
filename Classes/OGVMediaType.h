//
//  OGVMediaType.h
//  OGVKit
//
//  Created by Brion on 6/21/2015.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

typedef NS_ENUM(NSUInteger, OGVCanPlay) {
	OGVCanPlayNo = 0,
	OGVCanPlayMaybe = 1,
	OGVCanPlayProbably = 2
};

@interface OGVMediaType : NSObject

@property (readonly) NSString *major;
@property (readonly) NSString *minor;
@property (readonly) NSArray *codecs;

- (instancetype)initWithString:(NSString *)string;
- (NSString *)asString;

@end
