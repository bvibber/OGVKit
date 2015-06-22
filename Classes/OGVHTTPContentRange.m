//
//  OGVHTTPContentRange.m
//  OGVKit
//
//  Created by Brion on 6/21/2015
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"
#import "OGVHTTPContentRange.h"

@implementation OGVHTTPContentRange

- (instancetype)initWithString:(NSString *)string;
{
    self = [super init];
    if (self) {
        [self parseContentRange:string];
    }
    return self;
}

- (void)parseContentRange:(NSString *)string
{
    NSString *pattern = @"^bytes (\\d+)-(\\d+)/(\\d+)";
    NSError *err = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&err];
    if (err) {
        NSLog(@"regex fail in OGVHTTPContentRange: %@", err);
        return;
    }
    NSTextCheckingResult *match = [regex firstMatchInString:string
                                                    options:0
                                                      range:NSMakeRange(0, [string length])];
    if (match) {
        NSString *start = [string substringWithRange:[match rangeAtIndex:1]];
        NSString *end = [string substringWithRange:[match rangeAtIndex:2]];
        NSString *total = [string substringWithRange:[match rangeAtIndex:3]];
        _start = [start longLongValue];
        _end = [end longLongValue];
        _total = [total longLongValue];
    }
}


@end
