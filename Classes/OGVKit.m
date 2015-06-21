//
//  OGVAudioFeeder.m
//  OGVKit
//
//  Created by Brion on 6/28/14.
//  Copyright (c) 2014 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

@implementation OGVKit

+ (OGVKit *)singleton
{
    static OGVKit *singleton;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [[OGVKit alloc] init];
    });
    return singleton;
}

- (NSBundle *)resourceBundle
{
	NSBundle *parentBundle = [NSBundle bundleForClass:[self class]];
	NSString *bundlePath = [parentBundle pathForResource:@"OGVKitResources" ofType:@"bundle"];;
	return [NSBundle bundleWithPath:bundlePath];
}

@end
