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
        OGVFrameView *frameView = [[OGVFrameView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        [self addSubview:frameView];
        self.frameView = frameView;
    }
    return self;
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        OGVFrameView *frameView = [[OGVFrameView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
        [self addSubview:frameView];
        self.frameView = frameView;
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

-(void)pause
{
    [state pause];
}

- (void)stop
{
    if (state) {
        [state cancel];
        state = nil;
    }
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
