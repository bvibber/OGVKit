//
//  OGVLinkedExampleItem.m
//  OGVKit
//
//  Created by Brion on 11/6/15.
//  Copyright © 2015 Brion Vibber. All rights reserved.
//

#import "OGVLinkedExampleItem.h"

@implementation OGVLinkedExampleItem
{
    NSURL *_url;
}

-(instancetype)initWithTitle:(NSString *)title URL:(NSURL *)url
{
    NSArray *pathComponents = url.pathComponents;
    NSString *filename = pathComponents[pathComponents.count - 1];

    self = [self initWithTitle:title filename:filename];
    if (self) {
        if (!url) {
            @throw [NSException exceptionWithName:@"OGVBadURLException" reason:@"passed nil URL" userInfo:nil];
        }
        _url = url;
    }
    return self;
}


-(NSArray *)formats
{
    return @[_url.pathExtension];
}

-(NSArray *)resolutionsForFormat:(NSString *)format
{
    return @[@"source"];
}

-(NSURL *)URLforVideoFormat:(NSString *)format resolution:(int)resolution
{
    return _url;
}

-(NSURL *)URLforAudioFormat:(NSString *)format
{
    return _url;
}

@end
