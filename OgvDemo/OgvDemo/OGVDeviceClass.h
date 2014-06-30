//
//  OGVDeviceClass.h
//  OgvDemo
//
//  Created by Brion on 6/30/14.
//  Copyright (c) 2014 Brion Vibber. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OGVDeviceClass : NSObject

-(BOOL)isSimulator;
-(BOOL)isAtLeastARMv7;
-(BOOL)isAtLeastARMv7s;
-(BOOL)isAtLeastARM64;

@end
