//
//  OGVViewController.m
//  OgvKit
//
//  Created by Brion Vibber on 02/08/2015.
//  Copyright (c) 2014 Brion Vibber. All rights reserved.
//

#import "OGVViewController.h"

@import AVFoundation;
@import AVKit;

@interface OGVViewController ()

@end

@implementation OGVViewController
{
    NSArray *sources;
    NSArray *resolutions;
    NSInteger selectedSource;
    BOOL useWebM;
    int resolution;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    useWebM = YES;
    resolution = 360;
    [self updateResolutions];
    sources = @[
                @{@"title": @"Wikipedia Visual Editor",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/c/c8/Sneak_Preview_-_Wikipedia_VisualEditor.webm/Sneak_Preview_-_Wikipedia_VisualEditor.webm" },
                @{@"title": @"Open Access",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/b/b7/How_Open_Access_Empowered_a_16-Year-Old_to_Make_Cancer_Breakthrough.ogv/How_Open_Access_Empowered_a_16-Year-Old_to_Make_Cancer_Breakthrough.ogv" },
                @{@"title": @"Curiosity (720p)",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/9/96/Curiosity%27s_Seven_Minutes_of_Terror.ogv/Curiosity%27s_Seven_Minutes_of_Terror.ogv",
                  @"resolution": @(720)},
                @{@"title": @"Curiosity (H.264 480p)",
                  @"URL": @"https://brionv.com/misc/OGVKit/Curiosity.480p.mp4",
                  @"original": @(YES)},
                @{@"title": @"Curiosity (H.264 720p)",
                  @"URL": @"https://brionv.com/misc/OGVKit/Curiosity.720p.mp4",
                  @"original": @(YES)},
                @{@"title": @"Wiki Makes Video (720p60)",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/8/89/Wiki_Makes_Video_Intro_4_26.webm/Wiki_Makes_Video_Intro_4_26.webm",
                  @"resolution": @(720)},
                @{@"title": @"Pumpjack (short)",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/d/d6/Pumpjack.webm/Pumpjack.webm" },
                @{@"title": @"Myopa (video only)",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/8/8b/Myopa_-_2015-05-02.webm/Myopa_-_2015-05-02.webm" },
                @{@"title": @"Bach (Ogg audio only)",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/e/ea/Bach_C_Major_Prelude_Werckmeister.ogg",
                  @"original": @(YES)}
                ];
    selectedSource = -1;

    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"generic"];
    
    self.player.delegate = self;
}

- (void)selectSource:(NSInteger)index
{
    selectedSource = index;
    if (selectedSource >= 0) {
        NSDictionary *source = sources[index];

        NSString *format;
        if (useWebM) {
            format = @"webm";
        } else {
            format = @"ogv";
        }
        if (source[@"resolution"]) {
            int max = [source[@"resolution"] intValue];
            if (resolution > max) {
                resolution = max;
                [self updateResolutions];
            }
        }
        NSString *target = [NSString stringWithFormat:@"%dp.%@", resolution, format];

        NSString *str = source[@"URL"];
        if (!source[@"original"]) {
            str = [NSString stringWithFormat:@"%@.%@", str, target];
        }

        NSLog(@"%@", str);
        NSURL *url = [NSURL URLWithString:str];

        if ([str hasSuffix:@".mp4"]) {
            // whee
            AVPlayer *mp4Player = [AVPlayer playerWithURL:url];
            AVPlayerViewController *mp4Controller = [[AVPlayerViewController alloc] init];

            mp4Controller.view.frame = self.player.frame;
            mp4Controller.player = mp4Player;
            [self.view addSubview:mp4Controller.view];

            [mp4Player play];
        } else {
            self.player.sourceURL = url;
            // @todo separate load & play...
            [self.player play];
        }
    }
}

- (IBAction)selectFormat:(id)sender {
    BOOL wasWebM = useWebM;
    useWebM = (self.formatSelector.selectedSegmentIndex == 0);
    if (wasWebM != useWebM) {
        [self updateResolutions];
        [self selectSource:selectedSource];
    }
}

- (void)updateResolutions
{
    // @todo get this info from mediawiki :)
    if (useWebM) {
        resolutions = @[@(360), @(480), @(720), @(1080)];
        if (resolution < 360) {
            resolution = 360
            ;
        }
    } else {
        resolutions = @[@(160), @(360), @(480)];
        if (resolution > 480) {
            resolution = 480;
        }
    }
    
    [self.resolutionSelector removeAllSegments];
    for (int i = 0; i < [resolutions count]; i++) {
        int res = [resolutions[i] intValue];
        NSString *title = [NSString stringWithFormat:@"%dp", res];
        [self.resolutionSelector insertSegmentWithTitle:title
                                                atIndex:i
                                               animated:NO];
        if (resolution == res) {
            self.resolutionSelector.selectedSegmentIndex = i;
        }
    }
}

- (IBAction)resolutionSelected:(id)sender {
    int oldResolution = resolution;
    resolution = [resolutions[self.resolutionSelector.selectedSegmentIndex] intValue];

    if (resolution != oldResolution) {
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
