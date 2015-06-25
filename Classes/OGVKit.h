//
//  OGVKit.h
//  OGVKit
//
//  Created by Brion on 6/25/14.
//  Copyright (c) 2014-2015 Brion Vibber. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

@class OGVKit;

#import "OGVQueue.h"
#import "OGVMediaType.h"

#import "OGVAudioFormat.h"
#import "OGVAudioBuffer.h"

#import "OGVVideoFormat.h"
#import "OGVVideoPlane.h"
#import "OGVVideoBuffer.h"

#import "OGVInputStream.h"
#import "OGVDecoder.h"

#import "OGVFrameView.h"
#import "OGVAudioFeeder.h"
#import "OGVPlayerState.h"

#import "OGVPlayerView.h"


/**
 * OGVKit utility class.
 */
@interface OGVKit : NSObject

/**
 * Return the OGVKit singleton, used for some internal library management.
 */
+ (OGVKit *)singleton;

/**
 * Load the OGVKitResources bundle in the executable.
 */
- (NSBundle *)resourceBundle;

/**
 * Register a new decoder class.
 * To auto-load the decoder in OGVPlayerState based on file type, the decoder
 * should respond appropriately on the +[OGVDecoder canPlayType:] method.
 */
- (void)registerDecoderClass:(Class<OGVDecoder>)decoderClass;

/**
 * Find an appropriate decoder module for the given media type specification.
 * May return nil if no suitable decoders.
 *
 * Beware that even if a decoder is returned, it may not work if the file is
 * not correctly labeled or the type was vague.
 */
- (OGVDecoder *)decoderForType:(OGVMediaType *)mediaType;

@end
