//
//  OGVExampleItem.h
//  OGVKit
//
//  Created by Brion on 6/25/15.
//  Copyright © 2015 Brion Vibber. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OGVExampleItem : NSObject

@property (readonly) NSString *title;
@property (readonly) NSString *filename;

@property float playbackPosition;

-(instancetype)initWithTitle:(NSString *)title filename:(NSString *)filename;

-(NSArray *)formats;
-(NSArray *)resolutionsForFormat:(NSString *)format;
-(NSURL *)URLforVideoFormat:(NSString *)format resolution:(int)resolution;
-(NSURL *)URLforAudioFormat:(NSString *)format;

@end
