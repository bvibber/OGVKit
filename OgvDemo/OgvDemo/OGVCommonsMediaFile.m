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
    NSString *urlStr = [NSString stringWithFormat:@"%@?action=query&prop=imageinfo%%7Ctranscodestatus&titles=File%%3A%@&iiprop=url%%7Csize%%7Cmediatype%%7Cmetadata&iiurlwidth=1280&iiurlheight=720&format=json",
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
            NSDictionary *imageinfo;
            for (NSDictionary *page in [pages objectEnumerator]) {
                imageinfo = page[@"imageinfo"][0];
            }
            NSLog(@"imageinfo: %@", imageinfo);
            
            _mediaType = imageinfo[@"mediatype"];
            _sourceURL = [NSURL URLWithString:imageinfo[@"url"]]; // todo: get the transcode!
            _thumbnailURL = [NSURL URLWithString:imageinfo[@"thumburl"]];
            
            _dataReady = YES;
        } else {
            NSLog(@"Error %@", connectionError);
        }
        completionBlock();
    }];
}

@end
