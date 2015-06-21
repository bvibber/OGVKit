//
//  OGVPlayerState.h
//  Pods
//
//  Created by Brion on 6/13/15.
//
//

@class OGVPlayerState;

@protocol OGVPlayerStateDelegate<NSObject>

-(void)ogvPlayerState:(OGVPlayerState *)state drawFrame:(OGVVideoBuffer *)buffer;

@optional
-(void)ogvPlayerStateDidLoadMetadata:(OGVPlayerState *)state;

@optional
-(void)ogvPlayerStateDidPlay:(OGVPlayerState *)state;

@optional
-(void)ogvPlayerStateDidPause:(OGVPlayerState *)sender;

@optional
-(void)ogvPlayerStateDidEnd:(OGVPlayerState *)state;

@end


@interface OGVPlayerState : NSObject

-(instancetype)initWithURL:(NSURL *)URL delegate:(id<OGVPlayerStateDelegate>)delegate;

-(void)play;
-(void)pause;
-(void)cancel;

@property (readonly) BOOL paused;
@property (readonly) float playbackPosition;

@end
