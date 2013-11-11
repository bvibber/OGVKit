//
//  OGVCommonsMediaFile.m
//  OgvDemo
//
//  Created by Brion on 11/10/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import "OGVCommonsMediaFile.h"

@implementation OGVCommonsMediaFile

- (id)initWithFilename:(NSString *)filename
{
    self = [super init];
    if (self) {
        _filename = filename;
        _dataReady = NO;
    }
    return self;
}

- (void)fetch:(void (^)())completionBlock
{
    NSString *baseUrlStr = @"https://commons.wikimedia.org/w/api.php";
    NSString *urlStr = [NSString stringWithFormat:@"%@?action=query&prop=videoinfo&titles=File%%3A%@&viprop=url%%7Csize%%7Cmediatype%%7Cmetadata%%7Cderivatives&viurlwidth=1280&viurlheight=720&format=json",
                        baseUrlStr,
                        [self.filename stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
    NSURL *url = [NSURL URLWithString:urlStr];
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    [NSURLConnection sendAsynchronousRequest:req queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        //
        if (connectionError == nil) {
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSLog(@"data: %@", dict);
            
            // query.pages.12345.imageinfo[0]
            NSDictionary *pages = dict[@"query"][@"pages"];
            NSDictionary *videoinfo;
            for (NSDictionary *page in [pages objectEnumerator]) {
                videoinfo = page[@"videoinfo"][0];
            }
            [self extractVideoInfo:videoinfo];
            
            _dataReady = YES;
        } else {
            NSLog(@"Error %@", connectionError);
        }
        completionBlock();
    }];
}

- (void)extractVideoInfo:(NSDictionary *)videoinfo
{
    NSLog(@"videoinfo: %@", videoinfo);

    _mediaType = videoinfo[@"mediatype"];
    _thumbnailURL = [NSURL URLWithString:videoinfo[@"thumburl"]];

    int targetHeight = 9999999;

    NSArray *derivatives = videoinfo[@"derivatives"];
    for (NSDictionary *item in derivatives) {
        // Warning: width, height, and bandwidth may be either NSNumber or NSString
        // happily, 'intValue' works on both
        int height = [item[@"height"] intValue];
        NSString *urlStr = item[@"src"];
        NSString *type = item[@"type"];
        NSLog(@"%d %@ %@", height, urlStr, type);
        if ([type isEqualToString:@"video/ogg; codecs=\"theora, vorbis\""] ||
            [type isEqualToString:@"video/ogg; codecs=\"theora\""] ||
            [type isEqualToString:@"audio/ogg; codecs=\"vorbis\""]) {
            if (height < targetHeight) {
                targetHeight = height;
                _sourceURL = [NSURL URLWithString:urlStr];
            }
        }
    }
    
}

@end
