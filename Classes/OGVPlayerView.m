//
//  OGVPlayerView.m
//  OGVKit
//
//  Created by Brion on 2/8/15.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

@import CoreText;
@import AVFoundation;

static NSString *kOGVPlayerTimeLabelEmpty = @"-:--";

// Icons from Font Awesome custom subset
static NSString *kOGVPlayerIconCharPlay = @"\ue800";
static NSString *kOGVPlayerIconCharStop = @"\ue801";
static NSString *kOGVPlayerIconCharPause = @"\ue802";
static NSString *kOGVPlayerIconCharToEnd = @"\ue803";
static NSString *kOGVPlayerIconCharToEndAlt = @"\ue804";
static NSString *kOGVPlayerIconCharToStart = @"\ue805";
static NSString *kOGVPlayerIconCharToStartAlt = @"\ue806";
static NSString *kOGVPlayerIconCharFastFw = @"\ue807";
static NSString *kOGVPlayerIconCharFastBw = @"\ue808";
static NSString *kOGVPlayerIconCharEject = @"\ue809";
static NSString *kOGVPlayerIconCharPlayCircled = @"\ue80a";
static NSString *kOGVPlayerIconCharPlayCircled2 = @"\ue80b";
static NSString *kOGVPlayerIconCharResizeFull = @"\ue80c";
static NSString *kOGVPlayerIconCharResizeSmall = @"\ue80d";
static NSString *kOGVPlayerIconCharVolumeOff = @"\ue810";
static NSString *kOGVPlayerIconCharVolumeDown = @"\ue811";
static NSString *kOGVPlayerIconCharVolumeUp = @"\ue812";
static NSString *kOGVPlayerIconCharCog = @"\ue814";
static NSString *kOGVPlayerIconCharExport = @"\ue817";
static NSString *kOGVPlayerIconCharResizeVertical = @"\ue818";

static BOOL OGVPlayerViewDidRegisterIconFont = NO;

static void releasePixelBufferBacking(void *releaseRefCon, const void *dataPtr, size_t dataSize, size_t numberOfPlanes, const void * _Nullable planeAddresses[])
{
    CFTypeRef buf = (CFTypeRef)releaseRefCon;
    CFRelease(buf);
}

@implementation OGVPlayerView

{
    NSURL *_sourceURL;
    OGVInputStream *_inputStream;
    OGVPlayerState *state;
    NSTimer *timeTimer;
    NSTimer *controlsTimeout;
    NSTimer *seekTimeout;
    BOOL seeking;
    AVSampleBufferDisplayLayer *displayLayer;
}

#pragma mark - Public methods

-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setup];
    }
    return self;
}

- (NSURL *)sourceURL
{
    return _sourceURL;
}

- (void)setSourceURL:(NSURL *)sourceURL
{
    self.inputStream = [OGVInputStream inputStreamWithURL:sourceURL];
}

- (OGVInputStream *)inputStream
{
    return _inputStream;
}

- (void)setInputStream:(OGVInputStream *)inputStream
{
    if (state) {
        [state cancel];
        [displayLayer flushAndRemoveImage];
        state = nil;
    }
    _inputStream = inputStream;
    _sourceURL = inputStream.URL;
    [self updateTimeLabel];
    if (_inputStream) {
        state = [[OGVPlayerState alloc] initWithInputStream:_inputStream delegate:self];
    }
}

-(void)play
{
    [state play];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification
                                                  object:nil];
    if (state) {
        [state cancel];
    }
}

-(BOOL)paused
{
    if (state) {
        return state.paused;
    } else {
        return NO;
    }
}

-(void)pause
{
    if (state) {
        [state pause];
    }
}

- (void)seek:(float)seconds
{
    if (state) {
        [state seek:seconds];
    }
}

- (float)playbackPosition
{
    if (state) {
        return state.playbackPosition;
    } else {
        return 0;
    }
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    displayLayer.frame = self.bounds;
}

#pragma mark - private methods

-(void)setup
{
    NSBundle *bundle = [[OGVKit singleton]
                        resourceBundle];

    if (!OGVPlayerViewDidRegisterIconFont) {
        NSURL *fontURL = [bundle URLForResource:@"ogvkit-iconfont" withExtension:@"ttf"];
        CTFontManagerRegisterFontsForURL((__bridge CFURLRef)fontURL, kCTFontManagerScopeProcess, nil);
        OGVPlayerViewDidRegisterIconFont = YES;
    }
    
    // Output layer
    displayLayer = [[AVSampleBufferDisplayLayer alloc] init];
    displayLayer.frame = self.bounds;
    [self.layer addSublayer:displayLayer];

    // Controls
    UINib *nib = [UINib nibWithNibName:@"OGVPlayerView" bundle:bundle];
    UIView *interface = [nib instantiateWithOwner:self options:nil][0];

    // can this be set in the nib?
    [self.pausePlayButton setTitleColor:[UIColor blackColor] forState:UIControlStateHighlighted];

    // ok load that nib into our view \o/
    interface.frame = self.bounds;
    interface.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:interface];

    NSDictionary *layoutViews = NSDictionaryOfVariableBindings(interface);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[interface]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:layoutViews]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[interface]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:layoutViews]];

    // Events
    UIGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                       action:@selector(onViewTapped:)];
    [self addGestureRecognizer:tap];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
}

- (IBAction)togglePausePlay:(id)sender
{
    if (state) {
        if (state.paused) {
            [state play];
        } else {
            [state pause];
        }
    }
}

-(void)onViewTapped:(id)obj
{
    if (state && !state.paused) {
        if ([self controlsAreHidden]) {
            [self showControls];
        } else if ([self controlsAreVisible]) {
            [self hideControls];
        } else {
            // controls are in transition; don't mess with them.
        }
    }
}

- (IBAction)onProgressSliderChanged:(id)sender {
    if (state.seekable) {
        seeking = YES;
        if (seekTimeout) {
            [seekTimeout invalidate];
        }
        seekTimeout = [NSTimer timerWithTimeInterval:0.25f target:self selector:@selector(onSeekTimeout:) userInfo:state repeats:NO];
        [[NSRunLoop currentRunLoop] addTimer:seekTimeout forMode:NSRunLoopCommonModes];

        [self updateTimeLabel];
    }
}

- (IBAction)onProgressSliderReleased:(id)sender {
    if (seeking) {
        if (seekTimeout) {
            [seekTimeout invalidate];
            seekTimeout = nil;

            float targetTime = self.progressSlider.value * state.duration;
            [state seek:targetTime];
            [self.activityIndicator startAnimating];
            self.activityIndicator.hidden = NO;
            // we'll pick this up in ogvPlayerStateDidSeek
        }
    }
}

-(void)onSeekTimeout:(NSTimer *)timer
{
    if (timer.userInfo == state) {
        float targetTime = self.progressSlider.value * state.duration;
        [state seek:targetTime];

        seekTimeout = nil;
    }
}

-(BOOL)controlsAreVisible
{
    return (self.controlBar.alpha == 1.0f);
}

-(BOOL)controlsAreHidden
{
    return (self.controlBar.alpha == 0.0f);
}

-(void)hideControls
{
     if ([self.delegate respondsToSelector:@selector(ogvPlayerControlsWillHide:)]) {
        [self.delegate ogvPlayerControlsWillHide:self];
    }

    [UIView animateWithDuration:0.5f animations:^{
        self.controlBar.alpha = 0.0001f;
    } completion:^(BOOL finished) {
        self.controlBar.alpha = 0.0f;
    }];
}

-(void)showControls
{
    if ([self.delegate respondsToSelector:@selector(ogvPlayerControlsWillShow:)]) {
        [self.delegate ogvPlayerControlsWillShow:self];
    }

    if (self.controlBar.alpha == 0.0f) {
        self.controlBar.alpha = 0.0001f;
    }
    [UIView animateWithDuration:0.5f animations:^{
        self.controlBar.alpha = 1.0f;
    }];
}

-(void)stopControlsTimeout
{
    if (controlsTimeout) {
        [controlsTimeout invalidate];
        controlsTimeout = nil;
    }
}

-(void)startControlsTimeout
{
    if (controlsTimeout) {
        [self stopControlsTimeout];
    }
    if (!controlsTimeout) {
        controlsTimeout = [NSTimer scheduledTimerWithTimeInterval:4.0f
                                                           target:self
                                                         selector:@selector(pingControlsTimeout:)
                                                         userInfo:nil
                                                          repeats:NO];
    }
}

-(void)pingControlsTimeout:(NSTimer *)timer
{
    if ([self controlsAreVisible]) {
        [self hideControls];
    }
}

-(void)appDidEnterBackground:(id)obj
{
    [self pause];
}

-(void)stopTimeTimer
{
    if (timeTimer) {
        [timeTimer invalidate];
        timeTimer = nil;
    }
}

-(void)startTimeTimer
{
    if (!timeTimer) {
        timeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                     target:self
                                                   selector:@selector(pingTimeTimer:)
                                                   userInfo:nil
                                                    repeats:YES];
    }
}

-(void)pingTimeTimer:(NSTimer *)timer
{
    [self updateTimeLabel];
}

-(void)updateTimeLabel
{
    if (state) {
        float duration = state.duration;
        float position;
        if (seeking) {
            position = self.progressSlider.value * duration;
        } else {
            position = state.playbackPosition;
            self.progressSlider.value = position / duration;
        }
        self.timeLabel.text = [self formatTime:position];

        if (duration < INFINITY) {
            self.timeRemainingLabel.text = [self formatTime:position - duration];
            self.progressSlider.enabled = state.seekable;
            self.progressSlider.hidden = NO;
        } else {
            self.timeRemainingLabel.text = @"";
            self.progressSlider.value = 0;
            self.progressSlider.hidden = YES;
        }
    } else {
        self.timeLabel.text = kOGVPlayerTimeLabelEmpty;
        self.timeRemainingLabel.text = @"";
        self.progressSlider.value = 0;
        self.progressSlider.hidden = YES;
    }
}

-(NSString *)formatTime:(float)seconds
{
    int rounded = (int)roundf(seconds);
    int min = rounded / 60;
    int sec = abs(rounded % 60);
    return [NSString stringWithFormat:@"%d:%02d", min, sec];
}

#pragma mark - OGVPlayerStateDelegate methods

- (void)ogvPlayerState:(OGVPlayerState *)sender drawFrame:(OGVVideoBuffer *)buffer
{
    if (sender == state) {
        size_t planeWidth[3] = {
            buffer.format.lumaWidth,
            buffer.format.chromaWidth,
            buffer.format.chromaWidth
        };
        size_t planeHeight[3] = {
            buffer.format.lumaHeight,
            buffer.format.chromaHeight,
            buffer.format.chromaHeight
        };
        size_t planeBytesPerRow[3] = {
            buffer.Y.stride,
            buffer.Y.stride,
            buffer.Y.stride
        };
        void *planeBaseAddress[4] = {
            buffer.Y.data.bytes,
            buffer.Y.data.bytes,
            buffer.Y.data.bytes
        };
        
        CVImageBufferRef imageBuffer;
        NSDictionary *opts = @{
            (NSString *)kCVPixelBufferExtendedPixelsLeftKey: @(buffer.format.pictureOffsetX),
            (NSString *)kCVPixelBufferExtendedPixelsTopKey: @(buffer.format.pictureOffsetY),
            (NSString *)kCVPixelBufferExtendedPixelsRightKey: @(buffer.format.frameWidth - buffer.format.pictureWidth - buffer.format.pictureOffsetX),
            (NSString *)kCVPixelBufferExtendedPixelsBottomKey: @(buffer.format.frameHeight - buffer.format.pictureHeight - buffer.format.pictureOffsetY),
            (NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}
        };
        //OSType ok = CVPixelBufferCreateWithPlanarBytes(NULL, buffer.format.frameWidth, buffer.format.frameHeight, kCVPixelFormatType_420YpCbCr8Planar, NULL, 0, 3, planeBaseAddress, planeWidth, planeHeight, planeBytesPerRow, releasePixelBufferBacking, CFBridgingRetain(buffer), (__bridge CFDictionaryRef _Nullable)(opts), &imageBuffer);
        //OSType ok = CVPixelBufferCreateWithPlanarBytes(NULL, buffer.format.frameWidth, buffer.format.frameHeight, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, NULL, 0, 2, planeBaseAddress, planeWidth, planeHeight, planeBytesPerRow, releasePixelBufferBacking, CFBridgingRetain(buffer), (__bridge CFDictionaryRef _Nullable)(opts), &imageBuffer);
        //OSType ok = CVPixelBufferCreate(NULL, buffer.format.frameWidth, buffer.format.frameHeight, kCVPixelFormatType_420YpCbCr8Planar, (__bridge CFDictionaryRef _Nullable)(opts), &imageBuffer);
        OSType ok = CVPixelBufferCreate(NULL, buffer.format.frameWidth, buffer.format.frameHeight, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, (__bridge CFDictionaryRef _Nullable)(opts), &imageBuffer);
        if (ok != kCVReturnSuccess) {
            NSLog(@"pixel buffer create FAILED %d", ok);
        }

        CVPixelBufferLockBaseAddress(imageBuffer, 0);

        int lumaWidth = buffer.format.lumaWidth;
        int lumaHeight = buffer.format.lumaHeight;
        unsigned char *lumaIn = buffer.Y.data.bytes;
        unsigned char *lumaOut = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
        size_t lumaInStride = buffer.Y.stride;
        size_t lumaOutStride = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
        for (int y = 0; y < lumaHeight; y++) {
            for (int x = 0; x < lumaWidth; x++) {
                lumaOut[x] = lumaIn[x];
            }
            lumaIn += lumaInStride;
            lumaOut += lumaOutStride;
        }
        
        int chromaWidth = buffer.format.chromaWidth;
        int chromaHeight = buffer.format.chromaHeight;
        unsigned char *chromaCbIn = buffer.Cb.data.bytes;
        unsigned char *chromaCrIn = buffer.Cr.data.bytes;
        unsigned char *chromaOut = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
        size_t chromaCbInStride = buffer.Cb.stride;
        size_t chromaCrInStride = buffer.Cr.stride;
        size_t chromaOutStride = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 1);
        for (int y = 0; y < chromaHeight; y++) {
            for (int x = 0; x < chromaWidth; x++) {
                chromaOut[x * 2] = chromaCbIn[x];
                chromaOut[x * 2 + 1] = chromaCrIn[x];
            }
            chromaCbIn += chromaCbInStride;
            chromaCrIn += chromaCrInStride;
            chromaOut += chromaOutStride;
        }

        
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        
        CMVideoFormatDescriptionRef formatDesc;
        ok = CMVideoFormatDescriptionCreateForImageBuffer(NULL, imageBuffer, &formatDesc);
        if (ok != 0) {
            NSLog(@"format desc FAILED %d", ok);
        }

        CMSampleTimingInfo sampleTiming;
        sampleTiming.duration = CMTimeMake((1.0 / 60) * 1000, 1000);
        sampleTiming.presentationTimeStamp = CMTimeMake(buffer.timestamp * 1000, 1000);
        sampleTiming.decodeTimeStamp = kCMTimeInvalid;

        CMSampleBufferRef sampleBuffer;
        ok = CMSampleBufferCreateForImageBuffer(NULL, imageBuffer, YES, NULL, NULL, formatDesc, &sampleTiming, &sampleBuffer);
        if (ok != 0) {
            NSLog(@"sample buffer FAILED %d", ok);
        }

        CMSetAttachment(sampleBuffer, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue, kCMAttachmentMode_ShouldPropagate);
        
        //NSLog(@"Layer %d %@", displayLayer.status, displayLayer.error);
        [displayLayer enqueueSampleBuffer:sampleBuffer];
        
    }
}

- (void)ogvPlayerStateDidLoadMetadata:(OGVPlayerState *)sender
{
    if (sender == state) {
        if ([self.delegate respondsToSelector:@selector(ogvPlayerDidLoadMetadata:)]) {
            [self.delegate ogvPlayerDidLoadMetadata:self];
        }
    }
}

- (void)ogvPlayerStateDidPlay:(OGVPlayerState *)sender
{
    if (sender == state) {
        [self.pausePlayButton setTitle:kOGVPlayerIconCharPause forState:UIControlStateNormal];
        [self.pausePlayButton setTitle:kOGVPlayerIconCharPause forState:UIControlStateHighlighted];
        [self startTimeTimer];
        [self updateTimeLabel];

        if (![self controlsAreVisible]) {
            [self showControls];
        }
        [self startControlsTimeout];

        if ([self.delegate respondsToSelector:@selector(ogvPlayerDidPlay:)]) {
            [self.delegate ogvPlayerDidPlay:self];
        }
    }
}

- (void)ogvPlayerStateDidPause:(OGVPlayerState *)sender
{
    if (sender == state) {
        [self.pausePlayButton setTitle:kOGVPlayerIconCharPlay forState:UIControlStateNormal];
        [self.pausePlayButton setTitle:kOGVPlayerIconCharPlay forState:UIControlStateHighlighted];
        [self updateTimeLabel];
        [self stopTimeTimer];

        if ([self controlsAreHidden]) {
            [self showControls];
        } else {
            [self stopControlsTimeout];
        }

        if ([self.delegate respondsToSelector:@selector(ogvPlayerDidPause:)]) {
            [self.delegate ogvPlayerDidPause:self];
        }
    }
}

- (void)ogvPlayerStateDidEnd:(OGVPlayerState *)sender
{
    if (sender == state) {
        if ([self.delegate respondsToSelector:@selector(ogvPlayerDidEnd:)]) {
            [self.delegate ogvPlayerDidEnd:self];
        }
    }
}

- (void)ogvPlayerStateDidSeek:(OGVPlayerState *)sender
{
    if (sender == state) {
        seeking = NO;
        self.activityIndicator.hidden = YES;
        [self.activityIndicator stopAnimating];
        [self updateTimeLabel];

        if ([self.delegate respondsToSelector:@selector(ogvPlayerDidSeek:)]) {
            [self.delegate ogvPlayerDidSeek:self];
        }
    }
}

- (void)ogvPlayerState:(OGVPlayerState *)state customizeURLRequest:(NSMutableURLRequest *)request
{
    if ([self.delegate respondsToSelector:@selector(ogvPlayer:customizeURLRequest:)]) {
        [self.delegate ogvPlayer:self customizeURLRequest:request];
    }
}

@end
