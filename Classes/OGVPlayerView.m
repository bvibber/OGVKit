//
//  OGVPlayerView.m
//  OGVKit
//
//  Created by Brion on 2/8/15.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import <OGVKit/OGVKit.h>

#import "OGVPlayerState.h"

@implementation OGVPlayerView

{
    NSURL *_sourceURL;
    OGVPlayerState *state;
}

#pragma mark - Public methods

-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupWithSize:frame.size];
    }
    return self;
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setupWithSize:self.frame.size];
    }
    return self;
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    self.frameView.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
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
    }
    _sourceURL = [sourceURL copy];
    if (_sourceURL) {
        state = [[OGVPlayerState alloc] initWithURL:_sourceURL delegate:self];
    } else {
        state = nil;
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

-(BOOL)playing
{
    if (state) {
        return state.playing;
    } else {
        return NO;
    }
}

-(void)pause
{
    if (state && state.playing) {
        [state pause];
    }
}

#pragma mark - private methods

-(void)setupWithSize:(CGSize)size
{
    OGVFrameView *frameView = [[OGVFrameView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)
                                                          context:[self createGLContext]];
    [self addSubview:frameView];
    self.frameView = frameView;
    
    UIGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                       action:@selector(onViewTapped:)];
    [self addGestureRecognizer:tap];

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
        if (state.playing) {
            [state pause];
        } else {
            [state play];
        }
    }
}

-(void)appDidEnterBackground:(id)obj
{
    [self pause];
}

#pragma mark - OGVPlayerStateDelegate methods

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
        if ([self.delegate respondsToSelector:@selector(ogvPlayerDidPlay:)]) {
            [self.delegate ogvPlayerDidPlay:self];
        }
    }
}

- (void)ogvPlayerState:(OGVPlayerState *)sender drawFrame:(OGVFrameBuffer *)buffer
{
    if (sender == state) {
        [self.frameView drawFrame:buffer];
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
