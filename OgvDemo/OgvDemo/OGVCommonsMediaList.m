//
//  OGVCommonsMediaList.m
//  OgvDemo
//
//  Created by Brion on 11/11/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import "OGVCommonsMediaList.h"

@implementation OGVCommonsMediaList

+ (NSArray *)list
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"motd" ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSArray *motdList = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [OGVCommonsMediaList reverseArray:motdList];
}

+ (NSArray *)listWithFilter:(NSString *)filter
{
    NSArray *list = [OGVCommonsMediaList list];
    return [list filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        NSDictionary *item = evaluatedObject;
        NSString *filename = item[@"filename"];
        NSRange range = [filename rangeOfString:filter options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch];
        return (range.location != NSNotFound);
    }]];
}

+ (NSArray *)reverseArray:(NSArray *)arr
{
    NSMutableArray *out = [[NSMutableArray alloc] initWithCapacity:[arr count]];
    for (id obj in [arr reverseObjectEnumerator]) {
        [out addObject:obj];
    }
    return [NSArray arrayWithArray:out];
}


@end
