//
//  OGVTableViewController.m
//  OgvDemo
//
//  Created by Brion on 11/10/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import "OGVTableViewController.h"
#import "OGVViewController.h"
#import "OGVCommonsMediaFile.h"
#import "OGVCommonsMediaList.h"

@interface OGVTableViewController ()

@end

@implementation OGVTableViewController {
    NSArray *items;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    NSLog(@"Registering...");
    [[NSNotificationCenter defaultCenter] addObserverForName:@"OGVPlayerOpenURL" object:[UIApplication sharedApplication] queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {

        NSLog(@"got OGVPlayerOpenURL notification");
        OGVViewController *player = [[UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil] instantiateViewControllerWithIdentifier:@"OGVPlayerViewController"];

        assert(note.userInfo[@"URL"]);
        player.mediaSourceURL = note.userInfo[@"URL"];
        [self.navigationController pushViewController:player animated:YES];
    }];
    
    [self loadList];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadList
{
    NSString *filter = self.searchBar.text;
    if ([filter length] > 0) {
        items = [OGVCommonsMediaList listWithFilter:filter];
    } else {
        items = [OGVCommonsMediaList list];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    // Configure the cell...
    NSDictionary *item = items[indexPath.item];
    cell.textLabel.text = item[@"filename"];
    cell.detailTextLabel.text = item[@"date"];
    
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

 */

#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = items[indexPath.item];
    NSString *filename = item[@"filename"];
    OGVCommonsMediaFile *mediaFile = [[OGVCommonsMediaFile alloc] initWithFilename:filename];
    [mediaFile fetch:^{
        NSURL *url = mediaFile.sourceURL;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"OGVPlayerOpenURL" object:[UIApplication sharedApplication] userInfo:@{@"URL": url}];
    }];
}

#pragma mark - Search bar delegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self loadList];
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    // Hide the keyboard
    [searchBar resignFirstResponder];
}

@end
