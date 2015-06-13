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
-(void)ogvPlayerState:(OGVPlayerState *state) drawFrame:(OGVFrameBuffer *)buffer;

@optional
-(void)ogvPlayerStateDidEnd:(OGVPlayerState *)state;

@end


@interface OGVPlayerState : NSObject

-(instancetype)initWithURL:(NSURL *)URL delegate:(OGVPlayerDelegate *)delegate;
-(void)cancel;

@end
