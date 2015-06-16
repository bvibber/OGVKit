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

    dispatch_semaphore_t waitingForDataSemaphore;
    NSRunLoop *downloadRunLoop;
}

#pragma mark - public methods

-(void)dealloc
{
    if (connection) {
        [connection cancel];
    }
}

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
        OGVStreamFileState oldState = _state;
        _state = state;
        
        if (self.delegate && state != oldState) {
            dispatch_async(dispatch_get_main_queue(), ^() {
                if ([self.delegate respondsToSelector:@selector(ogvStreamFileStateChanged:)]) {
                    [self.delegate ogvStreamFileStateChanged:self];
                }
            });
        }
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
        BOOL wasAvailable = _dataAvailable;
        _dataAvailable = dataAvailable;
        
        if (waitingForDataSemaphore) {
            dispatch_semaphore_signal(waitingForDataSemaphore);
        }
        if (self.delegate && !wasAvailable && dataAvailable) {
            dispatch_async(dispatch_get_main_queue(), ^() {
                if ([self.delegate respondsToSelector:@selector(ogvStreamFileDataAvailable:)]) {
                    [self.delegate ogvStreamFileDataAvailable:self];
                }
            });
        }
    }
}

-(NSUInteger)bytesAvailable
{
    @synchronized (timeLock) {
        return [self queuedDataSize];
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
    NSLog(@"STARTING DOWNLOAD REQUESTED");
    @synchronized (timeLock) {
        assert(!connection);
        assert(!downloadRunLoop);
        
        [NSThread detachNewThreadSelector:@selector(startDownloadThread:)
                                 toTarget:self
                               withObject:nil];
    }
}

-(void)cancel
{
    [connection cancel];
}

-(NSData *)readBytes:(NSUInteger)nBytes blocking:(BOOL)blocking
{
    NSData *data = nil;
    BOOL blockingWait = NO;

    @synchronized (timeLock) {
        NSUInteger bytesAvailable = self.bytesAvailable;
        if (bytesAvailable >= nBytes) {
            data = [self dequeueBytes:nBytes];
        } else if (blocking) {
            // ...
            blockingWait = YES;
        } else if (bytesAvailable) {
            // Non-blocking, return as much data as we have.
            data = [self dequeueBytes:bytesAvailable];
        } else {
            // Non-blocking, and there is no data.
            data = nil;
        }
    }

    if (blockingWait) {
        [self waitForBytesAvailable:nBytes];
        data = [self dequeueBytes:nBytes];
    }
    return data;
}

#pragma mark - private methods

-(void)startDownloadThread:(id)obj
{
    NSLog(@"download starting...");

    @synchronized (timeLock) {
        downloadRunLoop = [NSRunLoop currentRunLoop];

        NSURLRequest *req = [NSURLRequest requestWithURL:self.URL];
        connection = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:NO];
        [connection scheduleInRunLoop:downloadRunLoop forMode:NSRunLoopCommonModes];
        [connection start];

        self.state = OGVStreamFileStateConnecting;
    }

    [downloadRunLoop run];

    NSLog(@"download thread complete!");
}

-(void)pingTimer:(id)obj
{
    NSLog(@"stupid timer");
}

-(void)waitForBytesAvailable:(NSUInteger)nBytes
{
    assert(waitingForDataSemaphore == NULL);
    waitingForDataSemaphore = dispatch_semaphore_create(0);
    while (YES) {
        @synchronized (timeLock) {
            NSLog(@"%ld %ld", self.bytesAvailable, nBytes);
            if (self.bytesAvailable >= nBytes) {
                waitingForDataSemaphore = nil;
                break;
            }
        }
        NSLog(@"waiting for data");
        dispatch_semaphore_wait(waitingForDataSemaphore,
                                //dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 4)
                                DISPATCH_TIME_FOREVER
                                );
        NSLog(@"post-wait");
    }
}

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

-(NSData *)dequeueBytes:(NSUInteger)nBytes
{
    @synchronized (timeLock) {
        NSMutableData *outputData = [[NSMutableData alloc] initWithCapacity:nBytes];
        while ([outputData length] < nBytes) {
            NSData *inputData = [self peekData];
            if (inputData) {
                NSUInteger inputSize = [inputData length];
                NSUInteger chunkSize = nBytes - [outputData length];

                if (inputSize <= chunkSize) {
                    [self dequeueData];
                    [outputData appendData:inputData];
                } else {
                    // Split the buffer for convenience. Not super efficient. :)
                    NSData *dataHead = [inputData subdataWithRange:NSMakeRange(0, chunkSize)];
                    NSData *dataTail = [inputData subdataWithRange:NSMakeRange(chunkSize, inputSize - chunkSize)];
                    inputDataQueue[0] = dataTail;
                    [outputData appendData:dataHead];
                }
            } else {
                // Ran out of input data.
                break;
            }
        }
        return outputData;
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
    NSLog(@"headers in");
    @synchronized (timeLock) {
        self.state = OGVStreamFileStateReading;
    }
}

- (void)connection:(NSURLConnection *)sender didReceiveData:(NSData *)data
{
    NSLog(@"data in");
    @synchronized (timeLock) {
        [self queueData:data];
        self.dataAvailable = YES;
        
        // @todo once moved to its own thread, throttle this connection!
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)sender
{
    NSLog(@"data done");
    @synchronized (timeLock) {
        self.state = OGVStreamFileStateDone;
        self.dataAvailable = ([inputDataQueue count] > 0);
        if (waitingForDataSemaphore) {
            dispatch_semaphore_signal(waitingForDataSemaphore);
        }
    }
}

@end
