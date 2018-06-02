//
//  OGVEncodingViewController.h
//  OGVKit Example
//
//  Created by Brion on 2/2/17.
//  Copyright © 2017 Brion Vibber. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OGVKit/OGVKit.h>

@interface OGVEncodingViewController : UIViewController <UINavigationControllerDelegate,UIImagePickerControllerDelegate>

@property (weak, nonatomic) IBOutlet UIButton *chooserButton;
@property (weak, nonatomic) IBOutlet OGVPlayerView *inputPlayer;
@property (weak, nonatomic) IBOutlet UIButton *transcodeButton;
@property (weak, nonatomic) IBOutlet UIProgressView *transcodeProgress;
@property (weak, nonatomic) IBOutlet OGVPlayerView *outputPlayer;
@property (weak, nonatomic) IBOutlet UILabel *fpsLabel;
@property (weak, nonatomic) IBOutlet UILabel *mbitsLabel;
@property (weak, nonatomic) IBOutlet UISegmentedControl *resolutionSelector;

@end
