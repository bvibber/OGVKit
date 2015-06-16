//
//  OGVPlayerView.m
//  OGVKit
//
//  Created by Brion on 2/8/15.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import <OGVKit/OGVKit.h>

#import "OGVPlayerState.h"

@import CoreText;

static NSString *kOGVPlayerTimeLabelEmpty = @"-:--";

// Icons from github-octicons font
static NSString *kOGVPlayerIconCharPlay = @"";
static NSString *kOGVPlayerIconCharPause = @"";

static BOOL OGVPlayerViewDidRegisterIconFont = NO;

@implementation OGVPlayerView

{
    NSURL *_sourceURL;
    OGVPlayerState *state;
    NSTimer *timeTimer;
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
    if (state) {
        [state cancel];
        [self.frameView clearFrame];
        state = nil;
    }
    _sourceURL = [sourceURL copy];
    [self updateTimeLabel];
    if (_sourceURL) {
        state = [[OGVPlayerState alloc] initWithURL:_sourceURL delegate:self];
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

#pragma mark - private methods

-(void)setup
{
    NSBundle *parentBundle = [NSBundle bundleForClass:[self class]];
    NSString *bundlePath = [parentBundle pathForResource:@"OGVKit" ofType:@"bundle"];;
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];

    if (!OGVPlayerViewDidRegisterIconFont) {
        NSURL *fontURL = [bundle URLForResource:@"octicons-local" withExtension:@"ttf"];
        CTFontManagerRegisterFontsForURL((__bridge CFURLRef)fontURL, kCTFontManagerScopeProcess, nil);
        OGVPlayerViewDidRegisterIconFont = YES;
    }

    UINib *nib = [UINib nibWithNibName:@"OGVPlayerView" bundle:bundle];
    UIView *interface = [nib instantiateWithOwner:self options:nil][0];

    // @todo move this into OGVFrameView
    self.frameView.context = [self createGLContext];

    interface.frame = self.bounds;
    interface.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:interface];

    // Events
    UIGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                       action:@selector(onViewTapped:)];
    [self.frameView addGestureRecognizer:tap];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
}

-(EAGLContext *)createGLContext
{
    EAGLContext *context;
    if (floor(NSFoundationVersionNumber) >= NSFoundationVersionNumber_iOS_7_0) {
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    }
    if (context == nil) {
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    }
    return context;
}

-(void)onViewTapped:(UIGestureRecognizer *)gestureRecognizer
{
    if (state) {
        if (state.paused) {
            [state play];
        } else {
            [state pause];
        }
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
        self.timeLabel.text = [self formatTime:state.playbackPosition];
    } else {
        self.timeLabel.text = kOGVPlayerTimeLabelEmpty;
    }
}

-(NSString *)formatTime:(float)seconds
{
    int rounded = (int)roundf(seconds);
    int min = rounded / 60;
    int sec = rounded % 60;
    return [NSString stringWithFormat:@"%d:%02d", min, sec];
}

#pragma mark - OGVPlayerStateDelegate methods

- (void)ogvPlayerState:(OGVPlayerState *)sender drawFrame:(OGVFrameBuffer *)buffer
{
    if (sender == state) {
        [self.frameView drawFrame:buffer];
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
        self.pausePlayButton.titleLabel.text = kOGVPlayerIconCharPause;
        [self startTimeTimer];
        [self updateTimeLabel];

        if ([self.delegate respondsToSelector:@selector(ogvPlayerDidPlay:)]) {
            [self.delegate ogvPlayerDidPlay:self];
        }
    }
}

- (void)ogvPlayerStateDidPause:(OGVPlayerState *)sender
{
    if (sender == state) {
        self.pausePlayButton.titleLabel.text = kOGVPlayerIconCharPlay;
        [self updateTimeLabel];
        [self stopTimeTimer];

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

@end
