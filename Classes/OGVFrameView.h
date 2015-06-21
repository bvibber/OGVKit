//
//  OGVFrameView.h
//  OgvDemo
//
//  Created by Brion on 11/6/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

@interface OGVFrameView : GLKView

- (void)drawFrame:(OGVVideoBuffer *)buffer;
- (void)clearFrame;

@end
