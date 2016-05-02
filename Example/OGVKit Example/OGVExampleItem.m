//
//  OGVExampleItem.m
//  OGVKit
//
//  Created by Brion on 6/25/15.
//  Copyright © 2015 Brion Vibber. All rights reserved.
//

#import "OGVExampleItem.h"

@implementation OGVExampleItem
{
}

-(instancetype)initWithTitle:(NSString *)title filename:(NSString *)filename
{
    self = [super init];
    if (self) {
        _title = title;
        _filename = filename;
    }
    return self;
}

-(NSArray *)formats
{
    @throw [NSException exceptionWithName:@"OGVNotImplemented" reason:@"Not implemented" userInfo:nil];
}

-(NSArray *)resolutionsForFormat:(NSString *)format
{
    @throw [NSException exceptionWithName:@"OGVNotImplemented" reason:@"Not implemented" userInfo:nil];
}

-(NSURL *)URLforVideoFormat:(NSString *)format resolution:(int)resolution
{
    @throw [NSException exceptionWithName:@"OGVNotImplemented" reason:@"Not implemented" userInfo:nil];
}

-(NSURL *)URLforAudioFormat:(NSString *)format
{
    @throw [NSException exceptionWithName:@"OGVNotImplemented" reason:@"Not implemented" userInfo:nil];
}

@end
