//
//  OGVPlayerState.h
//  Pods
//
//  Created by Brion on 6/13/15.
//
//

@class OGVPlayerState;

@protocol OGVPlayerStateDelegate<NSObject>

@optional
-(void)ogvPlayerStateDidLoadMetadata:(OGVPlayerState *)state;

@optional
-(void)ogvPlayerStateDidPlay:(OGVPlayerState *)state;

-(void)ogvPlayerState:(OGVPlayerState *)state drawFrame:(OGVFrameBuffer *)buffer;

@optional
-(void)ogvPlayerStateDidEnd:(OGVPlayerState *)state;

@end


@interface OGVPlayerState : NSObject

@property (readonly) BOOL playing;

-(instancetype)initWithURL:(NSURL *)URL delegate:(id<OGVPlayerStateDelegate>)delegate;
-(void)play;
-(void)pause;
-(void)cancel;

@end
