//
//  OGVViewController.h
//  OgvDemo
//
//  Created by Brion on 11/2/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OGVFrameView.h"

@interface OGVViewController : UIViewController <NSURLConnectionDataDelegate>

@property (weak, nonatomic) IBOutlet OGVFrameView *frameView;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;

@property NSURL *mediaSourceURL;

@end
