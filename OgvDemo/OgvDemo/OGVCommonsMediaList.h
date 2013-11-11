//
//  OGVCommonsMediaList.h
//  OgvDemo
//
//  Created by Brion on 11/11/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OGVCommonsMediaList : NSObject

+ (NSArray *)list;
+ (NSArray *)listWithFilter:(NSString *)filter;

@end
