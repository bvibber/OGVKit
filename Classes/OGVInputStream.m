//
//  OGVInputStream.h
//  OGVKit
//
//  Created by Brion on 6/16/15.
//  Copyright (c) 2015-2016 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

@interface OGVInputStream (Private)
@property (readonly) NSObject *timeLock;
@property (nonatomic) NSURL *URL;
@property (nonatomic) OGVInputStreamState state;
@property (nonatomic) OGVMediaType *mediaType;
@property (nonatomic) int64_t length;
@property (nonatomic) BOOL seekable;
@property (nonatomic) BOOL dataAvailable;
@property (nonatomic) int64_t bytePosition;
@property (nonatomic) NSUInteger bytesAvailable;
@end

@implementation OGVInputStream

{
    NSObject *_timeLock;
    NSURL *_URL;
    OGVInputStreamState _state;
    OGVMediaType *_mediaType;
    int64_t _length;
    BOOL _seekable;
    BOOL _dataAvailable;
    int64_t _bytePosition;
    NSUInteger _bytesAvailable;
}

#pragma mark - getters/setters

-(NSObject *)timeLock
{
    return _timeLock;
}

-(void)setTimeLock:(NSObject *)timeLock
{
    _timeLock = timeLock;
}

-(NSURL *)URL
{
    return _URL;
}

-(void)setURL:(NSURL *)URL
{
    _URL = URL;
}

-(OGVInputStreamState)state
{
    @synchronized (self.timeLock) {
        return _state;
    }
}

-(void)setState:(OGVInputStreamState)state
{
    @synchronized (self.timeLock) {
        OGVInputStreamState oldState = _state;
        _state = state;
        
        if (self.delegate && state != oldState) {
            dispatch_async(dispatch_get_main_queue(), ^() {
                if ([self.delegate respondsToSelector:@selector(OGVInputStreamStateChanged:)]) {
                    [self.delegate OGVInputStreamStateChanged:self];
                }
            });
        }
    }
}

-(BOOL)dataAvailable
{
    @synchronized (self.timeLock) {
        return _dataAvailable;
    }
}

-(void)setDataAvailable:(BOOL)dataAvailable
{
    @synchronized (self.timeLock) {
        BOOL wasAvailable = _dataAvailable;
        _dataAvailable = dataAvailable;
        
        if (self.delegate && !wasAvailable && dataAvailable) {
            dispatch_async(dispatch_get_main_queue(), ^() {
                if ([self.delegate respondsToSelector:@selector(OGVInputStreamDataAvailable:)]) {
                    [self.delegate OGVInputStreamDataAvailable:self];
                }
            });
        }
    }
}

-(NSUInteger)bytesAvailable
{
    @synchronized (self.timeLock) {
        return _bytesAvailable;
    }
}

-(void)setBytesAvailable:(NSUInteger)bytesAvailable
{
    @synchronized (self.timeLock) {
        _bytesAvailable = bytesAvailable;
    }
}

-(int64_t)bytePosition
{
    @synchronized (self.timeLock) {
        return _bytePosition;
    }
}

-(void)setBytePosition:(int64_t)bytePosition
{
    @synchronized (self.timeLock) {
        _bytePosition = bytePosition;
    }
}

-(void)setMediaType:(OGVMediaType *)mediaType
{
    @synchronized (self.timeLock) {
        _mediaType = mediaType;
    }
}

-(OGVMediaType *)mediaType
{
    @synchronized (self.timeLock) {
        return _mediaType;
    }
}

-(void)setSeekable:(BOOL)seekable
{
    @synchronized (self.timeLock) {
        _seekable = seekable;
    }
}

-(BOOL)seekable
{
    @synchronized (self.timeLock) {
        return _seekable;
    }
}

-(int64_t)length
{
    @synchronized (self.timeLock) {
        return _length;
    }
}

-(void)setLength:(int64_t)length
{
    @synchronized (self.timeLock) {
        _length = length;
    }
}

#pragma mark - public methods

-(instancetype)initWithURL:(NSURL *)URL
{
    self = [super init];
    if (self) {
        _timeLock = [[NSObject alloc] init];
        _URL = URL;
        _state = OGVInputStreamStateInit;
        _dataAvailable = NO;
    }
    return self;
}

-(void)start
{
    // no-op
}

-(void)restart
{
    // no-op
}

-(void)cancel
{
    // no-op
}

-(NSData *)readBytes:(NSUInteger)nBytes blocking:(BOOL)blocking
{
    return nil;
}

-(void)seek:(int64_t)offset blocking:(BOOL)blocking
{
    // no-op
}

@end
