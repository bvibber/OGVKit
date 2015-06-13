//
//  OGVViewController.h
//  OgvKit
//
//  Created by Brion Vibber on 02/08/2015.
//  Copyright (c) 2014 Brion Vibber. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OGVKit/OGVKit.h>

@interface OGVViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet OGVPlayerView *player;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end
