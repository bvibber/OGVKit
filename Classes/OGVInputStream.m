//
//  OGVInputStream.h
//  OGVKit
//
//  Created by Brion on 6/16/15.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"
#import "OGVHTTPContentRange.h"

static const NSUInteger kOGVInputStreamBufferSize = 1024 * 1024;

@interface OGVInputStream (Private)
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
    NSObject *timeLock;

    NSURL *_URL;
    OGVInputStreamState _state;
    OGVMediaType *_mediaType;
    int64_t _length;
    BOOL _seekable;
    BOOL _dataAvailable;
    int64_t _bytePosition;
    NSUInteger _bytesAvailable;

    NSURLConnection *connection;
    NSMutableArray *inputDataQueue;
    BOOL doneDownloading;

    dispatch_semaphore_t waitingForDataSemaphore;
}

#pragma mark - getters/setters

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
    @synchronized (timeLock) {
        return _state;
    }
}

-(void)setState:(OGVInputStreamState)state
{
    @synchronized (timeLock) {
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
    @synchronized (timeLock) {
        return _dataAvailable;
    }
}

-(void)setDataAvailable:(BOOL)dataAvailable
{
    @synchronized (timeLock) {
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
    @synchronized (timeLock) {
        return _bytesAvailable;
    }
}

-(void)setBytesAvailable:(NSUInteger)bytesAvailable
{
    @synchronized (timeLock) {
        _bytesAvailable = bytesAvailable;
    }
}

-(int64_t)bytePosition
{
    @synchronized (timeLock) {
        return _bytePosition;
    }
}

-(void)setBytePosition:(int64_t)bytePosition
{
    @synchronized (timeLock) {
        _bytePosition = bytePosition;
    }
}

-(void)setMediaType:(OGVMediaType *)mediaType
{
    @synchronized (timeLock) {
        _mediaType = mediaType;
    }
}

-(OGVMediaType *)mediaType
{
    @synchronized (timeLock) {
        return _mediaType;
    }
}

-(void)setSeekable:(BOOL)seekable
{
    @synchronized (timeLock) {
        _seekable = seekable;
    }
}

-(BOOL)seekable
{
    @synchronized (timeLock) {
        return _seekable;
    }
}

-(int64_t)length
{
    @synchronized (timeLock) {
        return _length;
    }
}

-(void)setLength:(int64_t)length
{
    @synchronized (timeLock) {
        _length = length;
    }
}

#pragma mark - public methods

-(instancetype)initWithURL:(NSURL *)URL
{
    self = [super init];
    if (self) {
        timeLock = [[NSObject alloc] init];
        _URL = URL;
        _state = OGVInputStreamStateInit;
        _dataAvailable = NO;
        inputDataQueue = [[NSMutableArray alloc] init];
    }
    return self;
}

-(void)dealloc
{
    if (connection) {
        [connection cancel];
    }
}

-(void)start
{
    @synchronized (timeLock) {
        assert(self.state == OGVInputStreamStateInit);

        self.state = OGVInputStreamStateConnecting;
        doneDownloading = NO;
        [self startDownload];
    }
}

-(void)cancel
{
    @synchronized (timeLock) {
        [connection cancel];
        connection = nil;
        self.state = OGVInputStreamStateCanceled;
    }
}

-(NSData *)readBytes:(NSUInteger)nBytes blocking:(BOOL)blocking
{
    NSData *data = nil;
    BOOL blockingWait = NO;

    @synchronized (timeLock) {
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
                NSLog(@"OGVInputStream reading in invalid state %d", (int)self.state);
                return nil;
        }

        NSUInteger bytesAvailable = self.bytesAvailable;
        //NSLog(@"nBytes: %ld; bytesAvailable: %ld", (long)nBytes, (long)bytesAvailable);
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

-(void)seek:(int64_t)offset blocking:(BOOL)blocking
{
    @synchronized (timeLock) {
        self.state = OGVInputStreamStateSeeking;

        [connection cancel];
        connection = nil;

        [inputDataQueue removeAllObjects];
        self.bytesAvailable = 0;
        self.dataAvailable = NO;

        self.bytePosition = offset;
        [self startDownload];
    }

    if (blocking) {
        [self waitForBytesAvailable:1];
    }
}

#pragma mark - private methods

-(void)startDownload
{
    @synchronized (timeLock) {
        assert(connection == nil);
        
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:self.URL];

        // Local NSURLConnection cache gets corrupted by use of Range: headers.
        // Possibly this is the same underlying bug as with Safari in ogv.js?
        //
        //   https://bugs.webkit.org/show_bug.cgi?id=82672
        //
        req.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

        [req addValue:[self nextRange] forHTTPHeaderField:@"Range"];
        NSLog(@"%@", [self nextRange]);

        connection = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:NO];
        [NSThread detachNewThreadSelector:@selector(startDownloadThread:)
                                 toTarget:self
                               withObject:nil];
    }
}

-(void)startDownloadThread:(id)obj
{
    NSRunLoop *downloadRunLoop = [NSRunLoop currentRunLoop];

    @synchronized (timeLock) {
        [connection scheduleInRunLoop:downloadRunLoop forMode:NSRunLoopCommonModes];
        [connection start];
    }
    [downloadRunLoop run];
}

-(NSString *)nextRange
{
    int64_t start = self.bytePosition + self.bytesAvailable;
    int64_t end = start + kOGVInputStreamBufferSize;
    return [NSString stringWithFormat:@"bytes=%lld-%lld", start, end - 1];
}

-(void)waitForBytesAvailable:(NSUInteger)nBytes
{
    assert(waitingForDataSemaphore == NULL);
    waitingForDataSemaphore = dispatch_semaphore_create(0);
    while (YES) {
        @synchronized (timeLock) {
            NSLog(@"waiting: have %ld, want %ld", (long)self.bytesAvailable, (long)nBytes);
            if (self.bytesAvailable >= nBytes ||
                doneDownloading ||
                self.state == OGVInputStreamStateDone ||
                self.state == OGVInputStreamStateFailed ||
                self.state == OGVInputStreamStateCanceled) {
                waitingForDataSemaphore = nil;
                break;
            }
        }

        dispatch_semaphore_wait(waitingForDataSemaphore,
                                DISPATCH_TIME_FOREVER);

    }
}

-(void)queueData:(NSData *)data
{
    @synchronized (timeLock) {
        [inputDataQueue addObject:data];
        self.bytesAvailable += [data length];

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
            self.bytesAvailable -= [inputData length];
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
        
        if (doneDownloading && nBytes > self.bytesAvailable) {
            nBytes = self.bytesAvailable;
        }

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
                    self.bytesAvailable -= [dataHead length];
                    [outputData appendData:dataHead];
                }
            } else {
                // Ran out of input data
                break;
            }
        }

        self.bytePosition += [outputData length];

        if (!connection) {
            if (doneDownloading) {
                if (self.bytesAvailable == 0) {
                    // Ran out of input data.
                    self.state = OGVInputStreamStateDone;
                }
            } else {
                if (self.bytesAvailable < kOGVInputStreamBufferSize) {
                    [self startDownload];
                }
            }
        }

        return outputData;
    }
}


#pragma mark - NSURLConnectionDataDelegate methods

- (void)connection:(NSURLConnection *)sender didReceiveResponse:(NSURLResponse *)response
{
    @synchronized (timeLock) {
        if (sender == connection) {
            switch (self.state) {
                case OGVInputStreamStateConnecting:
                    self.mediaType = [[OGVMediaType alloc] initWithString:response.MIMEType];

                    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                        NSDictionary *headers = httpResponse.allHeaderFields;
                        NSInteger statusCode = httpResponse.statusCode;
                        
                        if (statusCode == 206) {
                            NSString *rangeHeader = headers[@"Content-Range"];
                            OGVHTTPContentRange *range = [[OGVHTTPContentRange alloc] initWithString:rangeHeader];
                            if (range.total) {
                                self.length = range.total;
                                self.seekable = YES;
                            }
                        } else if (statusCode == 200) {
                            NSString *contentLength = headers[@"Content-Length"];
                            if (contentLength) {
                                self.length = [contentLength longLongValue];
                            }
                            self.seekable = NO;
                        } else {
                            NSLog(@"Unexpected HTTP status %d in OGVInputStream", (int)statusCode);
                            [connection cancel];
                            connection = nil;
                            self.state = OGVInputStreamStateFailed;
                            return;
                        }
                    } else {
                        self.seekable = NO;
                        if (response.expectedContentLength != NSURLResponseUnknownLength) {
                            self.length = response.expectedContentLength;
                        }
                    }
                    self.state = OGVInputStreamStateReading;
                    break;
                case OGVInputStreamStateReading:
                case OGVInputStreamStateSeeking:
                    // We're just continuing a stream already connected to.
                    break;
                default:
                    NSLog(@"invalid state %d in -[OGVInputStream connection:didReceiveResponse:]", (int)self.state);
            }
        }
    }
}

- (void)connection:(NSURLConnection *)sender didReceiveData:(NSData *)data
{
    @synchronized (timeLock) {
        if (sender == connection) {
            [self queueData:data];

            if (waitingForDataSemaphore) {
                dispatch_semaphore_signal(waitingForDataSemaphore);
            }
        }
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)sender
{
    @synchronized (timeLock) {
        if (sender == connection) {
            if (self.length) {
                doneDownloading = self.bytePosition + self.bytesAvailable >= self.length;
            } else {
                doneDownloading = YES;
            }
            if (doneDownloading) {
                self.dataAvailable = ([inputDataQueue count] > 0);
                if (waitingForDataSemaphore) {
                    dispatch_semaphore_signal(waitingForDataSemaphore);
                }
            }
            connection = nil;
        }
    }
}

- (void)connection:(NSURLConnection *)sender didFailWithError:(NSError *)error
{
    @synchronized (timeLock) {
        if (sender == connection) {
            // @todo if we're in read state, let us read out the rest of data
            // already fetched!
            self.state = OGVInputStreamStateFailed;
            self.dataAvailable = ([inputDataQueue count] > 0);

            if (waitingForDataSemaphore) {
                dispatch_semaphore_signal(waitingForDataSemaphore);
            }
        }
    }
}

@end
