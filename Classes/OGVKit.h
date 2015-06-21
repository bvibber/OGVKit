//
//  OGVKit.h
//  OGVKit
//
//  Created by Brion on 6/25/14.
//  Copyright (c) 2014 Brion Vibber. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

@class OGVKit;

#import "OGVAudioFormat.h"
#import "OGVAudioBuffer.h"

#import "OGVVideoFormat.h"
#import "OGVVideoPlane.h"
#import "OGVVideoBuffer.h"

#import "OGVStreamFile.h"
#import "OGVDecoder.h"

#import "OGVFrameView.h"
#import "OGVAudioFeeder.h"
#import "OGVPlayerState.h"

#import "OGVPlayerView.h"


@interface OGVKit : NSObject

+ (OGVKit *)singleton;
- (NSBundle *)resourceBundle;

@end
