//
//  OGVFrameView.h
//  OGVKit
//
//  Created by Brion on 11/6/13.
//  Copyright (c) 2013-2015 Brion Vibber. All rights reserved.
//

@interface OGVFrameView : GLKView

- (void)drawFrame:(OGVVideoBuffer *)buffer;
- (void)clearFrame;

@end
