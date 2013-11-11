//
//  OGVCommonsMediaFile.h
//  OgvDemo
//
//  Created by Brion on 11/10/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OGVCommonsMediaFile : NSObject

@property (readonly) NSString *filename;
@property (readonly) BOOL dataReady;

@property (readonly) NSString *mediaType;
@property (readonly) NSURL *sourceURL;
@property (readonly) NSURL *thumbnailURL;

- (id)initWithFilename:(NSString *)filename;

- (void)fetch:(void (^)())completionBlock;

@end
