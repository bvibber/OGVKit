//
//  OGVFileInputStream.h
//  OGVKit
//
//  Copyright (c) 2016 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"
#import "OGVFileInputStream.h"

@interface OGVFileInputStream (Private)
@property (nonatomic) NSURL *URL;
@property (nonatomic) OGVInputStreamState state;
@property (nonatomic) OGVMediaType *mediaType;
@property (nonatomic) int64_t length;
@property (nonatomic) BOOL seekable;
@property (nonatomic) BOOL dataAvailable;
@property (nonatomic) int64_t bytePosition;
@property (nonatomic) NSUInteger bytesAvailable;
@end

@implementation OGVFileInputStream
{
    FILE *file;
}

#pragma mark - public methods

-(instancetype)initWithURL:(NSURL *)URL
{
    if (!URL.isFileURL) {
        @throw [NSError errorWithDomain:@"com.brionv.OGVKit"
                                   code:1000
                               userInfo:@{@"URL": URL}];
    }
    self = [super initWithURL:URL];
    return self;
}

-(void)start
{
    assert(self.state == OGVInputStreamStateInit);
    self.state = OGVInputStreamStateConnecting;

    NSString *ext = [self.URL.pathExtension lowercaseString];
    if ([ext isEqualToString:@"webm"]) {
        self.mediaType = [[OGVMediaType alloc] initWithString:@"video/webm"];
    } else if ([ext isEqualToString:@"ogg"]) {
        self.mediaType = [[OGVMediaType alloc] initWithString:@"audio/ogg"];
    } else if ([ext isEqualToString:@"oga"]) {
        self.mediaType = [[OGVMediaType alloc] initWithString:@"audio/ogg"];
    } else if ([ext isEqualToString:@"ogv"]) {
        self.mediaType = [[OGVMediaType alloc] initWithString:@"video/ogg"];
    } else if ([ext isEqualToString:@"mp4"]) {
        self.mediaType = [[OGVMediaType alloc] initWithString:@"video/mp4"];
    } else if ([ext isEqualToString:@"m4a"]) {
        self.mediaType = [[OGVMediaType alloc] initWithString:@"audio/mp4"];
    } else if ([ext isEqualToString:@"m4v"]) {
        self.mediaType = [[OGVMediaType alloc] initWithString:@"video/mp4"];
    }

    file = fopen([self.URL.path UTF8String], "rb");
    if (file) {
        fseek(file, 0, SEEK_END);
        self.length = ftell(file);
        fseek(file, 0, SEEK_SET);
        self.seekable = YES;
        self.bytePosition = 0;
        self.state = OGVInputStreamStateReading;
    } else {
        self.state = OGVInputStreamStateFailed;
    }
}

-(void)restart
{
    [self cancel];

    self.state = OGVInputStreamStateInit;
    [self start];
}

-(void)cancel
{
    self.state = OGVInputStreamStateCanceled;
    if (file) {
        fclose(file);
        file = NULL;
    }
}

-(NSData *)readBytes:(NSUInteger)nBytes blocking:(BOOL)blocking
{
    switch (self.state) {
        case OGVInputStreamStateInit:
        case OGVInputStreamStateConnecting:
        case OGVInputStreamStateReading:
            // We're ok.
            break;
        case OGVInputStreamStateDone:
            // We're done so there's no data. Return it now!
            return nil;
        case OGVInputStreamStateSeeking:
        case OGVInputStreamStateFailed:
        case OGVInputStreamStateCanceled:
            [OGVKit.singleton.logger errorWithFormat:@"OGVFileInputStream reading in invalid state %d", (int)self.state];
            @throw [NSError errorWithDomain:@"com.brionv.OGVKit"
                                       code:1000
                                   userInfo:@{@"URL": self.URL}];
            return nil;
    }

    // @todo support non-blocking reads from local filesystem
    if (feof(file)) {
        self.state = OGVInputStreamStateDone;
        return nil;
    } else {
        void *buffer = malloc(nBytes);
        size_t bytesRead = fread(buffer, 1, nBytes, file);
        
        self.bytePosition += bytesRead;

        return [NSData dataWithBytesNoCopy:buffer length:bytesRead freeWhenDone:YES];
    }
}

-(void)seek:(int64_t)offset blocking:(BOOL)blocking
{
    // @todo support non-blocking reads from local filesystem
    fseeko(file, offset, SEEK_SET);
    self.bytePosition = offset;
    self.state = OGVInputStreamStateReading;
}

@end
