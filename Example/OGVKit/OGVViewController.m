//
//  OGVViewController.m
//  OgvKit
//
//  Created by Brion Vibber on 02/08/2015.
//  Copyright (c) 2014 Brion Vibber. All rights reserved.
//

#import "OGVViewController.h"

@interface OGVViewController ()

@end

@implementation OGVViewController
{
    NSArray *sources;
    NSInteger selectedSource;
    BOOL useWebM;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    sources = @[
                @{@"title": @"Wiki Makes Video (60fps)",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/8/89/Wiki_Makes_Video_Intro_4_26.webm/Wiki_Makes_Video_Intro_4_26.webm"},
                @{@"title": @"Wikipedia Visual Editor",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/c/c8/Sneak_Preview_-_Wikipedia_VisualEditor.webm/Sneak_Preview_-_Wikipedia_VisualEditor.webm" },
                @{@"title": @"Open Access",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/b/b7/How_Open_Access_Empowered_a_16-Year-Old_to_Make_Cancer_Breakthrough.ogv/How_Open_Access_Empowered_a_16-Year-Old_to_Make_Cancer_Breakthrough.ogv" },
                @{@"title": @"Seven Minutes of Terror",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/9/96/Curiosity%27s_Seven_Minutes_of_Terror.ogv/Curiosity%27s_Seven_Minutes_of_Terror.ogv" },
                @{@"title": @"Pumpjack (short)",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/d/d6/Pumpjack.webm/Pumpjack.webm" },
                @{@"title": @"Myopa (video only)",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/8/8b/Myopa_-_2015-05-02.webm/Myopa_-_2015-05-02.webm" },
                @{@"title": @"Bach (Ogg audio only)",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/e/ea/Bach_C_Major_Prelude_Werckmeister.ogg",
                  @"audioOnly": @(YES)}
                ];
    selectedSource = -1;

    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"generic"];
    
    self.player.delegate = self;
}

- (void)selectSource:(NSInteger)index
{
    selectedSource = index;
    if (selectedSource >= 0) {
        NSString *target;
        if (useWebM) {
            target = @"360p.webm";
        } else {
            target = @"360p.ogv";
        }

        NSString *str = sources[index][@"URL"];
        if (!sources[index][@"audioOnly"]) {
            str = [NSString stringWithFormat:@"%@.%@", str, target];
        }

        NSLog(@"%@", str);

        self.player.sourceURL = [NSURL URLWithString:str];
        // @todo separate load & play...
        [self.player play];
    }
}

- (IBAction)selectFormat:(id)sender {
    BOOL wasWebM = useWebM;
    useWebM = (self.formatSelector.selectedSegmentIndex == 1);
    if (wasWebM != useWebM) {
        [self selectSource:selectedSource];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITableViewDataSource methods

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"generic"];
    NSDictionary *source = sources[indexPath.item];
    cell.textLabel.text = source[@"title"];
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    return [sources count];
}

#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self selectSource:indexPath.item];
}

#pragma mark - OGVPlayerDelegate methods

- (void)ogvPlayerDidEnd:(OGVPlayerView *)sender
{
    NSInteger nextSource = selectedSource + 1;
    if (nextSource < [sources count]) {
        [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForItem:nextSource inSection:0]
                                    animated:YES
                              scrollPosition:UITableViewScrollPositionNone];
        [self selectSource:nextSource];
    }
}

@end
