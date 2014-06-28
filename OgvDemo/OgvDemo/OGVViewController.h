//
//  OGVViewController.h
//  OgvDemo
//
//  Created by Brion on 11/2/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OGVFrameView.h"
#import "OGVCommonsMediaFile.h"

@interface OGVViewController : UIViewController <NSURLConnectionDataDelegate>

@property (weak, nonatomic) IBOutlet OGVFrameView *frameView;
@property (weak, nonatomic) IBOutlet UIButton *playPauseButton;
@property (weak, nonatomic) IBOutlet UISlider *positionSlider;
@property (weak, nonatomic) IBOutlet UISegmentedControl *resolutionPicker;

@property OGVCommonsMediaFile *mediaSource;
@property NSURL *mediaSourceURL;

- (IBAction)resolutionPicked:(UISegmentedControl *)sender;

@end
