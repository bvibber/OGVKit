//
//  OGVPlayerView.h
//  OgvKit
//
//  Created by Brion on 2/8/15.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import <UIKit/UIKit.h>

@class OGVPlayerView;

@protocol OGVPlayerDelegate <NSObject>

@optional
-(void)ogvPlayerDidLoadMetadata:(OGVPlayerView *)sender;

@optional
-(void)ogvPlayerDidPlay:(OGVPlayerView *)sender;

@optional
-(void)ogvPlayerDidEnd:(OGVPlayerView *)sender;

@end


@interface OGVPlayerView : UIView <OGVPlayerStateDelegate>

@property (weak) id<OGVPlayerDelegate> delegate;
@property (weak) OGVFrameView *frameView;

@property (nonatomic) NSURL *sourceURL;

@property (readonly) BOOL paused;

-(void)play;
-(void)pause;

@end
