//
//  OGVInputStream.h
//  OGVKit
//
//  Created by Brion on 6/16/15.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

@class OGVInputStream;

@protocol OGVInputStreamDelegate <NSObject>

@optional
-(void)OGVInputStreamDataAvailable:(OGVInputStream *)sender;

@optional
-(void)OGVInputStreamStateChanged:(OGVInputStream *)sender;

@end

typedef NS_ENUM(int, OGVInputStreamState) {
    OGVInputStreamStateInit = 0,
    OGVInputStreamStateConnecting = 1,
    OGVInputStreamStateReading = 2,
    OGVInputStreamStateSeeking = 3,
    OGVInputStreamStateDone = 4,
    OGVInputStreamStateFailed = 5,
    OGVInputStreamStateCanceled = 6
};

@interface OGVInputStream : NSObject <NSURLConnectionDataDelegate>

@property (weak) id<OGVInputStreamDelegate> delegate;

@property (readonly) NSURL *URL;
@property (readonly) OGVInputStreamState state;
@property (readonly) OGVMediaType *mediaType;
@property (readonly) int64_t length;
@property (readonly) BOOL seekable;
@property (readonly) BOOL dataAvailable;
@property (readonly) int64_t bytePosition;
@property (readonly) NSUInteger bytesAvailable;

-(instancetype)initWithURL:(NSURL *)URL;
-(void)start;
-(void)restart;
-(void)cancel;

/**
 * In non-blocking mode or at the end of a file,
 * you may receive fewer bytes than requested.
 *
 * If no data is available, returns nil.
 */
-(NSData *)readBytes:(NSUInteger)nBytes blocking:(BOOL)blocking;

-(void)seek:(int64_t)offset blocking:(BOOL)blocking;

@end
