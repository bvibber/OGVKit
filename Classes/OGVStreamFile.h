//
//  OGVStreamFile.h
//  OGVKit
//
//  Created by Brion on 6/16/15.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

@class OGVStreamFile;

@protocol OGVStreamFileDelegate <NSObject>

@optional
-(void)ogvStreamFileDataAvailable:(OGVStreamFile *)sender;

@optional
-(void)ogvStreamFileStateChanged:(OGVStreamFile *)sender;

@end

typedef NS_ENUM(NSUInteger, OGVStreamFileState) {
    OGVStreamFileStateInit = 0,
    OGVStreamFileStateConnecting = 1,
    OGVStreamFileStateFailed = 2,
    OGVStreamFileStateDone = 3,
    OGVStreamFileStateReading = 4,
    OGVStreamFileStateSeeking = 5
};

@interface OGVStreamFile : NSObject <NSURLConnectionDataDelegate>

@property (weak, nonatomic) id<OGVStreamFileDelegate> delegate;

@property (nonatomic) NSUInteger bufferSize;

@property (readonly) NSURL *URL;
@property (readonly) OGVStreamFileState state;
@property (readonly) OGVMediaType *mediaType;

@property (readonly) BOOL dataAvailable;
@property (readonly) NSUInteger bytesAvailable;
@property (readonly) NSUInteger bytePosition;

-(instancetype)initWithURL:(NSURL *)URL;
-(void)start;
-(void)cancel;

/**
 * In non-blocking mode or at the end of a file,
 * you may receive fewer bytes than requested.
 *
 * If no data is available, returns nil.
 */
-(NSData *)readBytes:(NSUInteger)nBytes blocking:(BOOL)blocking;

@end
