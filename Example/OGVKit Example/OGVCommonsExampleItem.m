//
//  OGVCommonsExampleItem.m
//  OGVKit
//
//  Created by Brion on 11/6/15.
//  Copyright © 2015 Brion Vibber. All rights reserved.
//

#import "OGVCommonsExampleItem.h"

@implementation OGVCommonsExampleItem
{
    NSDictionary *json;
    NSArray *derivatives;
}

-(instancetype)initWithTitle:(NSString *)title filename:(NSString *)filename
{
    self = [super initWithTitle:title filename:filename];
    return self;
}

-(NSArray *)formats
{
    [self fetchData];
    NSMutableArray *formats = [[NSMutableArray alloc] init];
    
    for (NSDictionary *derivative in derivatives) {
        NSString *key = derivative[@"transcodekey"];
        if (key) {
            int dres;
            NSString *dformat;
            if ([self parseTranscodeKey:derivative[@"transcodekey"] format:&dformat resolution:&dres]) {
                if (![formats containsObject:dformat]) {
                    [formats addObject:dformat];
                }
            } else {
                [formats addObject:derivative[@"transcodekey"]];
            }
        }
    }
    
    // hack for audio files for now
    NSString *ext = [[self.filename pathExtension] lowercaseString];
    if ([ext isEqualToString:@"oga"]) {
        ext = @"ogg";
    }
    if (![formats containsObject:ext]) {
        [formats addObject:ext];
    }
    return formats;
}

-(NSArray *)resolutionsForFormat:(NSString *)format
{
    [self fetchData];
    NSMutableArray *resolutions = [[NSMutableArray alloc] init];
    
    for (NSDictionary *derivative in derivatives) {
        NSString *key = derivative[@"transcodekey"];
        if (key) {
            NSString *dformat;
            int dres;
            if ([self parseTranscodeKey:derivative[@"transcodekey"] format:&dformat resolution:&dres]) {
                if ([format isEqualToString:dformat]) {
                    [resolutions addObject:@(dres)];
                }
            }
        }
    }
    return resolutions;
}

-(NSURL *)URLforVideoFormat:(NSString *)format resolution:(int)resolution
{
    [self fetchData];
    NSString *key = [NSString stringWithFormat:@"%dp.%@", resolution, format];
    return [self URLforTranscodeKey:key];
}

-(NSURL *)URLforAudioFormat:(NSString *)format
{
    [self fetchData];
    NSURL *url = [self URLforTranscodeKey:format];
    if (url) {
        return url;
    } else {
        // currently Commons doesn't produce transcodes for most ogg audio sources,
        // unless they're not Vorbis in the original.
        return [self URLforTranscodeKey:nil];
    }
}

#pragma mark - private methods

- (void)fetchData
{
    if (json == nil) {
        NSString *apiBase = @"https://commons.wikimedia.org/w/api.php";
        NSDictionary *params = @{@"action": @"query",
                                 @"prop": @"videoinfo",
                                 @"format": @"json",
                                 @"formatversion": @"2",
                                 @"viprop": @"derivatives",
                                 @"titles": [@"File:" stringByAppendingString:self.filename]};
        NSURL *apiURL = [self URLWithBase:apiBase queryStringParams:params];
        
        // yes, sync fetch is poor practice
        NSData *data = [NSData dataWithContentsOfURL:apiURL];
        json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        derivatives = json[@"query"][@"pages"][0][@"videoinfo"][0][@"derivatives"];
    }
}

- (NSURL *)URLWithBase:(NSString *)base queryStringParams:(NSDictionary *)params
{
    NSMutableString *str = [NSMutableString stringWithString:base];
    BOOL first = YES;
    for (NSString *key in [params keyEnumerator]) {
        NSString *val = params[key];
        if (first) {
            [str appendString:@"?"];
            first = false;
        } else {
            [str appendString:@"&"];
        }
        [str appendString:[self encodeParam:key]];
        [str appendString:@"="];
        [str appendString:[self encodeParam:val]];
    }
    return [NSURL URLWithString:str];
}

- (NSString *)encodeParam:(NSString *)str
{
    str = [str stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    str = [str stringByReplacingOccurrencesOfString:@":" withString:@"%3A"];
    str = [str stringByReplacingOccurrencesOfString:@"?" withString:@"%3F"];
    return str;
}

- (NSURL *)URLforTranscodeKey:(NSString *)key
{
    for (NSDictionary *derivative in derivatives) {
        if (key == nil) {
            if (derivative[@"transcodekey"]) {
                continue;
            }
        } else {
            if (![derivative[@"transcodekey"] isEqualToString:key]) {
                continue;
            }
        }
        return [NSURL URLWithString:derivative[@"src"]];
    }
    return nil;
}

- (BOOL)parseTranscodeKey:(NSString *)key format:(NSString **)format resolution:(int *)resolution
{
    NSString *pattern = @"^(\\d+)p\\.(.*)$";
    NSError *err = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&err];
    if (err) {
        NSLog(@"regex fail in OGVExampleItem: %@", err);
        return NO;
    }
    NSTextCheckingResult *match = [regex firstMatchInString:key
                                                    options:0
                                                      range:NSMakeRange(0, [key length])];
    if (match) {
        *resolution = [[key substringWithRange:[match rangeAtIndex:1]] intValue];
        *format = [key substringWithRange:[match rangeAtIndex:2]];
        return YES;
    }
    
    return NO;
}

@end
