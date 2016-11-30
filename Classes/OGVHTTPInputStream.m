//
//  OGVHTTPInputStream.h
//  OGVKit
//
//  Created by Brion on 6/16/15.
//  Copyright (c) 2015-2016 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"
#import "OGVHTTPInputStream.h"
#import "OGVHTTPContentRange.h"

static const NSUInteger kOGVInputStreamBufferSizeSeeking = 1024 * 64;
static const NSUInteger kOGVInputStreamBufferSizeReading = 1024 * 1024;

@interface OGVHTTPInputStream (Private)
@property (nonatomic) NSObject *timeLock;
@property (nonatomic) NSURL *URL;
@property (nonatomic) OGVInputStreamState state;
@property (nonatomic) OGVMediaType *mediaType;
@property (nonatomic) int64_t length;
@property (nonatomic) BOOL seekable;
@property (nonatomic) BOOL dataAvailable;
@property (nonatomic) int64_t bytePosition;
@property (nonatomic) NSUInteger bytesAvailable;
@end

@implementation OGVHTTPInputStream
{
    NSUInteger rangeSize;
    
    NSURLConnection *connection;
    NSMutableArray *inputDataQueue;
    BOOL doneDownloading;
    
    dispatch_semaphore_t waitingForDataSemaphore;
}


#pragma mark - public methods

-(instancetype)initWithURL:(NSURL *)URL
{
    self = [super initWithURL:URL];
    if (self) {
        rangeSize = kOGVInputStreamBufferSizeSeeking; // start small, we may need to seek away
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
    @synchronized (self.timeLock) {
        assert(self.state == OGVInputStreamStateInit);
        
        self.state = OGVInputStreamStateConnecting;
        [self startDownload];
    }
}

-(void)restart
{
    @synchronized (self.timeLock) {
        self.state = OGVInputStreamStateInit;
        [self resetState];
        [self startDownload];
    }
}

-(void)cancel
{
    @synchronized (self.timeLock) {
        self.state = OGVInputStreamStateCanceled;
        [connection cancel];
        connection = nil;
    }
}

-(NSData *)readBytes:(NSUInteger)nBytes blocking:(BOOL)blocking
{
    NSData *data = nil;
    
    @synchronized (self.timeLock) {
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
    }
    
    if (blocking) {
        [self waitForBytesAvailable:nBytes];
    }
    
    @synchronized (self.timeLock) {
        data = [self dequeueBytes:nBytes];
        [self continueDownloadIfNeeded];
        return data;
    }
}

-(void)seek:(int64_t)offset blocking:(BOOL)blocking
{
    @synchronized (self.timeLock) {
        switch (self.state) {
            case OGVInputStreamStateReading:
            case OGVInputStreamStateDone:
                // ok
                break;
            case OGVInputStreamStateFailed:
            case OGVInputStreamStateCanceled:
                // todo: make sure we actually got initial state on the stream somewheres
                break;
            default:
                NSLog(@"Unexpected input stream state for seeking: %d", self.state);
                return;
        }
        
        self.state = OGVInputStreamStateSeeking;
        self.bytePosition = offset;
        [self resetState];
        [self startDownload];
    }
    
    if (blocking) {
        // Actually fetch some data before we return, or we're likely to get
        // lots of short hung connections when jumping about.
        [self waitForBytesAvailable:kOGVInputStreamBufferSizeSeeking];
        
        if (self.state != OGVInputStreamStateReading) {
            NSLog(@"Unexpected input stream state after seeking: %d", self.state);
        }
    }
}

#pragma mark - private methods

-(void)resetState
{
    @synchronized (self.timeLock) {
        [connection cancel];
        connection = nil;
        
        [inputDataQueue removeAllObjects];
        self.bytesAvailable = 0;
        self.dataAvailable = NO;
        
        rangeSize = kOGVInputStreamBufferSizeSeeking;
    }
}

-(void)startDownload
{
    @synchronized (self.timeLock) {
        assert(connection == nil);
        
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:self.URL];
        
        // Local NSURLConnection cache gets corrupted by use of Range: headers.
        // Possibly this is the same underlying bug as with Safari in ogv.js?
        //
        //   https://bugs.webkit.org/show_bug.cgi?id=82672
        //
        req.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        
        [req addValue:[self nextRange] forHTTPHeaderField:@"Range"];
        NSLog(@"Range %lld: %@", (int64_t)rangeSize, [self nextRange]);
        
        // Allow caller to add custom HTTP headers etc
        if ([self.delegate respondsToSelector:@selector(OGVInputStream:customizeURLRequest:)]) {
            [self.delegate OGVInputStream:self customizeURLRequest:req];
        }
        
        doneDownloading = NO;
        connection = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:NO];
        [NSThread detachNewThreadSelector:@selector(startDownloadThread:)
                                 toTarget:self
                               withObject:connection];
    }
}

-(void)startDownloadThread:(id)obj
{
    NSRunLoop *downloadRunLoop = [NSRunLoop currentRunLoop];
    
    @synchronized (self.timeLock) {
        if (connection == obj) {
            [connection scheduleInRunLoop:downloadRunLoop forMode:NSRunLoopCommonModes];
            [connection start];
        }
    }
    
    [downloadRunLoop run];
    
    @synchronized (self.timeLock) {
        // In case one of our download attempts silently failed while
        // we were waiting on it for a blocking read, it would be nice
        // to know about it.
        if (connection == obj && waitingForDataSemaphore) {
            NSLog(@"URL download may have failed? poking foreground thread with a stick...");
            dispatch_semaphore_signal(waitingForDataSemaphore);
        }
    }
}

-(NSString *)nextRange
{
    int64_t start = self.bytePosition + self.bytesAvailable;
    int64_t end = start + rangeSize; // if this exceeds the file end, that's ok. we'll find out when response comes back
    return [NSString stringWithFormat:@"bytes=%lld-%lld", start, end - 1];
}

-(BOOL)waitForBytesAvailable:(NSUInteger)nBytes
{
    const NSTimeInterval maxTimeout = 10.0;
    int tries = 0;
    
    for (NSDate *start = [NSDate date]; fabs([start timeIntervalSinceNow]) < maxTimeout; tries++) {
        if (tries > 0) {
            @synchronized (self.timeLock) {
                [self continueDownloadIfNeeded];
                
                assert(waitingForDataSemaphore == NULL);
                waitingForDataSemaphore = dispatch_semaphore_create(0);
            }
            
            NSLog(@"waiting: at %ld/%ld: have %ld, want %ld; done %d, state %d, rangeSize %d", (long)self.bytePosition, (long)(long)self.length, self.bytesAvailable, (long)nBytes, (int)doneDownloading, (int)self.state, (int)rangeSize);
            
            dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC);
            dispatch_semaphore_wait(waitingForDataSemaphore,
                                    timeout);
            
            @synchronized (self.timeLock) {
                waitingForDataSemaphore = nil;
            }
        }
        
        @synchronized (self.timeLock) {
            if (self.bytesAvailable >= nBytes ||
                doneDownloading ||
                self.state == OGVInputStreamStateDone ||
                self.state == OGVInputStreamStateFailed ||
                self.state == OGVInputStreamStateCanceled) {
                
                if (tries) {
                    NSLog(@"data received; continuing!");
                }
                return YES;
            }
        }
    }
    
    NSLog(@"Blocking i/o timed out; may be wonky");
    self.state = OGVInputStreamStateFailed;
    return NO;
}

-(void)queueData:(NSData *)data
{
    @synchronized (self.timeLock) {
        [inputDataQueue addObject:data];
        self.bytesAvailable += [data length];
        
        if ([inputDataQueue count] == 1) {
            self.dataAvailable = YES;
        }
    }
}

-(NSData *)peekData
{
    @synchronized (self.timeLock) {
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
    @synchronized (self.timeLock) {
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
    @synchronized (self.timeLock) {
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
        
        return outputData;
    }
}

-(void)continueDownloadIfNeeded
{
    @synchronized (self.timeLock) {
        if (!connection) {
            if (doneDownloading) {
                if (self.bytesAvailable == 0) {
                    // Ran out of input data.
                    self.state = OGVInputStreamStateDone;
                }
            } else {
                if (self.bytesAvailable < rangeSize) {
                    // After a successful seek-related read range completes,
                    // bump our stream size back up
                    if (rangeSize < kOGVInputStreamBufferSizeReading) {
                        rangeSize = MIN(rangeSize * 2, kOGVInputStreamBufferSizeReading);
                    }
                    [self startDownload];
                }
            }
        }
    }
}

#pragma mark - NSURLConnectionDataDelegate methods

- (void)connection:(NSURLConnection *)sender didReceiveResponse:(NSHTTPURLResponse *)response
{
    @synchronized (self.timeLock) {
        if (sender == connection) {
            int statusCode = (int)response.statusCode;
            NSDictionary *headers = response.allHeaderFields;
            NSString *contentLength = headers[@"Content-Length"];
            NSString *rangeHeader = headers[@"Content-Range"];
            OGVHTTPContentRange *range = nil;
            
            if (statusCode == 206) {
                range = [[OGVHTTPContentRange alloc] initWithString:rangeHeader];
            }
            
            switch (self.state) {
                case OGVInputStreamStateConnecting:
                    self.mediaType = [[OGVMediaType alloc] initWithString:response.MIMEType];
                    
                    switch (statusCode) {
                        case 200: // 'OK' - non-seekable stream
                            if (contentLength) {
                                self.length = [contentLength longLongValue];
                            }
                            self.seekable = NO;
                            self.state = OGVInputStreamStateReading;
                            break;
                            
                        case 206: // 'Partial Content' - Range: requests work
                            if (range.valid) {
                                self.length = range.total;
                                self.seekable = YES;
                                self.state = OGVInputStreamStateReading;
                            } else {
                                self.state = OGVInputStreamStateFailed;
                            }
                            break;
                            
                        default:
                            self.state = OGVInputStreamStateFailed;
                    }
                    
                    break;
                    
                case OGVInputStreamStateSeeking:
                    // Reconnected. THE BYTES MUST FLOW
                    self.state = OGVInputStreamStateReading;
                    break;
                    
                case OGVInputStreamStateReading:
                    // We're just continuing a stream already connected to.
                    break;
                    
                default:
                    NSLog(@"invalid state %d in -[OGVInputStream connection:didReceiveResponse:]", (int)self.state);
                    self.state = OGVInputStreamStateFailed;
            }
            
            if (self.state == OGVInputStreamStateFailed) {
                NSLog(@"Unexpected HTTP status %d in OGVInputStream connection", statusCode);
                [connection cancel];
                connection = nil;
            }
            
            NSLog(@"RESPONSE %d RECEIVED (%d available)", statusCode, (int)self.bytesAvailable);
            if (waitingForDataSemaphore) {
                dispatch_semaphore_signal(waitingForDataSemaphore);
            }
        }
    }
}

- (void)connection:(NSURLConnection *)sender didReceiveData:(NSData *)data
{
    @synchronized (self.timeLock) {
        if (sender == connection) {
            [self queueData:data];
            
            //NSLog(@"didReceiveData: %d (%d available)", (int)[data length], (int)self.bytesAvailable);
            if (waitingForDataSemaphore) {
                dispatch_semaphore_signal(waitingForDataSemaphore);
            }
        }
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)sender
{
    @synchronized (self.timeLock) {
        if (sender == connection) {
            if (self.length) {
                doneDownloading = self.bytePosition + self.bytesAvailable >= self.length;
            } else {
                doneDownloading = YES;
            }
            if (doneDownloading) {
                self.dataAvailable = ([inputDataQueue count] > 0);
            }
            connection = nil;
            
            //NSLog(@"didFinishLoading! (%d available)", (int)self.bytesAvailable);
            if (waitingForDataSemaphore) {
                dispatch_semaphore_signal(waitingForDataSemaphore);
            }
        }
    }
}

- (void)connection:(NSURLConnection *)sender didFailWithError:(NSError *)error
{
    @synchronized (self.timeLock) {
        if (sender == connection) {
            // @todo if we're in read state, let us read out the rest of data
            // already fetched!
            self.state = OGVInputStreamStateFailed;
            self.dataAvailable = ([inputDataQueue count] > 0);
            
            //NSLog(@"didFailWithError!");
            if (waitingForDataSemaphore) {
                dispatch_semaphore_signal(waitingForDataSemaphore);
            }
        }
    }
}


@end
