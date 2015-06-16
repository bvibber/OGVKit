//
//  OGVStreamFile.h
//  OGVKit
//
//  Created by Brion on 6/16/15.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#include "OGVKit/OGVKit.h"

@interface OGVStreamFile (Private)
@property (nonatomic) NSURL *URL;
@property (nonatomic) OGVStreamFileState state;
@property (nonatomic) BOOL dataAvailable;
@end

@implementation OGVStreamFile
{
    NSObject *timeLock;

    NSURL *_URL;
    OGVStreamFileState _state;
    BOOL _dataAvailable;

    NSURLConnection *connection;
    NSMutableArray *inputDataQueue;
    
}

#pragma mark - public methods

-(NSURL *)URL
{
    return _URL;
}

-(void)setURL:(NSURL *)URL
{
    _URL = URL;
}

-(OGVStreamFileState)state
{
    @synchronized (timeLock) {
        return _state;
    }
}

-(void)setState:(OGVStreamFileState)state
{
    @synchronized (timeLock) {
        _state = state;
    }
}

-(BOOL)dataAvailable
{
    @synchronized (timeLock) {
        return _dataAvailable;
    }
}

-(void)setDataAvailable:(BOOL)dataAvailable
{
    @synchronized (timeLock) {
        _dataAvailable = dataAvailable;
    }
}

-(instancetype)initWithURL:(NSURL *)URL
{
    self = [super init];
    if (self) {
        timeLock = [[NSObject alloc] init];
        self.URL = URL;
        self.bufferSize = 65536;
        self.state = OGVStreamFileStateInit;
        self.dataAvailable = NO;
        inputDataQueue = [[NSMutableArray alloc] init];
    }
    return self;
}

-(void)start
{
    @synchronized (timeLock) {
        NSURLRequest *req = [NSURLRequest requestWithURL:self.URL];
        connection = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:NO];
        [connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        [connection start];
        self.state = OGVStreamFileStateConnecting;
    }
}

-(void)cancel
{
    [connection cancel];
}

-(NSData *)readBytes:(NSUInteger)nBytes blocking:(BOOL)blocking
{
    if (blocking) {
        NSLog(@"blocking reads not yet implemented");
        abort();
    }
    
    @synchronized (timeLock) {
        NSData *buffer = [self peekData];
        
        NSUInteger bufferLen = [buffer length];
        if (bufferLen <= nBytes) {
            [self dequeueData];
            return buffer;
        } else {
            // Split the buffer for convenience. Not super efficient. :)
            NSData *dataHead = [buffer subdataWithRange:NSMakeRange(0, nBytes)];
            NSData *dataTail = [buffer subdataWithRange:NSMakeRange(nBytes, bufferLen - nBytes)];
            inputDataQueue[0] = dataTail;
            return dataHead;
        }
    }
}

#pragma mark - private methods

-(void)queueData:(NSData *)data
{
    @synchronized (timeLock) {
        [inputDataQueue addObject:data];
        if ([inputDataQueue count] == 1) {
            self.dataAvailable = YES;
        }
    }
}

-(NSData *)peekData
{
    @synchronized (timeLock) {
        if ([inputDataQueue count] > 0) {
            NSData *inputData = inputDataQueue[0];
            return inputData;
        } else {
            return nil;
        }
    }
}

-(NSData *)dequeueData
{
    @synchronized (timeLock) {
        NSData *inputData = [self peekData];
        if (inputData) {
            [inputDataQueue removeObjectAtIndex:0];
        }
        if ([inputDataQueue count] == 0) {
            self.dataAvailable = NO;
        }
        return inputData;
    }
}

-(NSUInteger)queuedDataSize
{
    NSUInteger nbytes = 0;
    for (NSData *data in inputDataQueue) {
        nbytes += [data length];
    }
    return nbytes;
}



#pragma mark - NSURLConnectionDataDelegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    @synchronized (timeLock) {
        self.state = OGVStreamFileStateReading;
    }
}

- (void)connection:(NSURLConnection *)sender didReceiveData:(NSData *)data
{
    BOOL pingDelegate = NO;

    @synchronized (timeLock) {
        if (!self.dataAvailable) {
            pingDelegate = YES;
        }
        [self queueData:data];
        
        // @todo once moved to its own thread, throttle this connection!
    }

    if (pingDelegate) {
        [self.delegate ogvStreamFileDataAvailable:self];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)sender
{
    @synchronized (timeLock) {
        self.state = OGVStreamFileStateDone;
        connection = nil;
    }
}

@end
