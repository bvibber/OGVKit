//
//  OGVMediaExampleItem.m
//  OGVKit Example
//
//  Created by Brion on 2/3/18.
//  Copyright © 2018 Brion Vibber. All rights reserved.
//

#import "OGVMediaExampleItem.h"

#import <CommonCrypto/CommonDigest.h>

@implementation OGVMediaExampleItem

{
    int resolution;
}

-(instancetype)initWithTitle:(NSString *)title
                    filename:(NSString *)filename
                  resolution:(int)resolution
{
    self = [super initWithTitle:title filename:filename];
    if (self) {
        self->resolution = resolution;
    }
    return self;
}

-(NSArray *)formats
{
    return @[@"ogv", @"webm", @"vp9.webm"];
}

-(NSArray *)resolutionsForFormat:(NSString *)format
{
    NSMutableArray *resolutions = [[NSMutableArray alloc] init];
    for (NSNumber *res in @[@160, @240, @360, @480, @720, @1080, @1440, @2160]) {
        if ([res intValue] <= self->resolution) {
            [resolutions addObject:res];
        }
    }
    return resolutions;
}

-(NSString *)calcMD5ForString:(NSString *)str
{
    const char *utf8 = [str UTF8String];
    unsigned char hash[CC_MD5_DIGEST_LENGTH];
    char hex[CC_MD5_DIGEST_LENGTH * 2 + 1];

    CC_MD5(utf8, (unsigned int)strlen(utf8), hash);

    // hex!
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        snprintf(hex + i * 2, 3, "%02x", hash[i]);
    }
    hex[CC_MD5_DIGEST_LENGTH - 1] = 0;

    return [NSString stringWithCString:hex encoding:NSUTF8StringEncoding];
}

-(NSURL *)URLforVideoFormat:(NSString *)format resolution:(int)resolution
{
    NSString *filename = [self.filename stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    NSString *md5 = [self calcMD5ForString:filename];
    NSString *urlEncodedTitle = [filename stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *url = [NSString stringWithFormat:@"https://media-streaming.wmflabs.org/clean/transcoded/%@/%@/%@/%@.%dp.%@",
                     [md5 substringToIndex:1],
                     [md5 substringToIndex:2],
                     urlEncodedTitle,
                     urlEncodedTitle,
                     resolution,
                     format];
    return [NSURL URLWithString:url];
}

-(NSURL *)URLforAudioFormat:(NSString *)format
{
    NSString *filename = [self.filename stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    NSString *md5 = [self calcMD5ForString:filename];
    NSString *urlEncodedTitle = [filename stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://media-streaming.wmflabs.org/clean/transcoded/%@/%@/%@/%@.%@",
                                 [md5 substringToIndex:1],
                                 [md5 substringToIndex:2],
                                 urlEncodedTitle,
                                 urlEncodedTitle,
                                 format]];
}


@end
