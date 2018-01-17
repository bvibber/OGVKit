//
//  OGVDataInputStream.h
//  OGVKit
//
//  Copyright (c) 2016 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"
#import "OGVDataInputStream.h"

@interface OGVDataInputStream (Private)
@property (nonatomic) NSURL *URL;
@property (nonatomic) OGVInputStreamState state;
@property (nonatomic) OGVMediaType *mediaType;
@property (nonatomic) int64_t length;
@property (nonatomic) BOOL seekable;
@property (nonatomic) BOOL dataAvailable;
@property (nonatomic) int64_t bytePosition;
@property (nonatomic) NSUInteger bytesAvailable;
@end

@implementation OGVDataInputStream
{
}

#pragma mark - public methods

-(instancetype)initWithData:(NSData *)data
{
    self = [super initWithURL:[NSURL URLWithString:@"blob:data"]];
    if (self) {
        self.data = data;
    }
    return self;
}

-(void)start
{
    self.state = OGVInputStreamStateConnecting;

    // Check magic numbers
    if (self.data.length < 4) {
        self.state = OGVInputStreamStateFailed;
        return;
    }
    const unsigned char *bytes = self.data.bytes;
    if (bytes[0] == 'O' && bytes[1] == 'g' && bytes[2] == 'g' && bytes[3] == 'S') {
        self.mediaType = [[OGVMediaType alloc] initWithString:@"video/ogg"];
    } else if (bytes[0] == 0x1a && bytes[1] == 0x45 && bytes[2] == 0xdf && bytes[3] == 0xa3) {
        self.mediaType = [[OGVMediaType alloc] initWithString:@"video/webm"];
    } else {
        self.state = OGVInputStreamStateFailed;
        return;
    }

    self.seekable = YES;
    self.bytePosition = 0;
    self.length = self.data.length;

    self.state = OGVInputStreamStateReading;
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
            [OGVKit.singleton.logger errorWithFormat:@"OGVDataInputStream reading in invalid state %d", (int)self.state ];
            @throw [NSError errorWithDomain:@"com.brionv.OGVKit"
                                       code:1000
                                   userInfo:@{@"URL": self.URL}];
            return nil;
    }
    
    if (self.bytePosition >= self.length) {
        self.state = OGVInputStreamStateDone;
        return nil;
    } else {
        int64_t bytesToRead = self.length - self.bytePosition;
        if (bytesToRead > nBytes) {
            bytesToRead = nBytes;
        }
        NSRange range = NSMakeRange(self.bytePosition, bytesToRead);
        
        self.bytePosition += bytesToRead;
        return [self.data subdataWithRange:range];
    }
}

-(void)seek:(int64_t)offset blocking:(BOOL)blocking
{
    self.bytePosition = offset;
    self.state = OGVInputStreamStateReading;
}

@end
