//
//  OGVTableViewController.h
//  OgvDemo
//
//  Created by Brion on 11/10/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OGVTableViewController : UITableViewController <UISearchBarDelegate>
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;
@property (strong, nonatomic) IBOutlet UITableView *tableView;

@end
