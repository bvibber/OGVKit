//
//  OGVViewController.m
//  OgvKit
//
//  Created by Brion Vibber on 02/08/2015.
//  Copyright (c) 2014-2015 Brion Vibber. All rights reserved.
//

#import "OGVViewController.h"

@interface OGVViewController ()

@end

@implementation OGVViewController
{
    NSArray *sources;
    NSArray *resolutions;
    NSInteger selectedSource;
    BOOL useWebM;
    int resolution;
    float lastPosition;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    useWebM = YES;
    resolution = 360;
    [self updateResolutions];
    sources = @[
                // Wikipedia stuff
                @{@"title": @"Wikipedia Visual Editor",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/c/c8/Sneak_Preview_-_Wikipedia_VisualEditor.webm/Sneak_Preview_-_Wikipedia_VisualEditor.webm" },
                @{@"title": @"¿Qué es Wikipédia?",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/1/1a/%C2%BFQu%C3%A9_es_Wikipedia%3F.ogv/%C2%BFQu%C3%A9_es_Wikipedia%3F.ogv",
                  @"resolution": @(720)},
                @{@"title": @"Wiki Makes Video (60fps)",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/8/89/Wiki_Makes_Video_Intro_4_26.webm/Wiki_Makes_Video_Intro_4_26.webm",
                  @"resolution": @(720)},

                // Third-party stuff
                @{@"title": @"Open Access",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/b/b7/How_Open_Access_Empowered_a_16-Year-Old_to_Make_Cancer_Breakthrough.ogv/How_Open_Access_Empowered_a_16-Year-Old_to_Make_Cancer_Breakthrough.ogv" },
                @{@"title": @"Curiosity's Seven Minutes of Terror",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/9/96/Curiosity%27s_Seven_Minutes_of_Terror.ogv/Curiosity%27s_Seven_Minutes_of_Terror.ogv",
                  @"resolution": @(720)},
                @{@"title": @"Hamilton Mixtape (60fps)",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/3/3d/Hamilton_Mixtape_%2812_May_2009_live_at_the_White_House%29_Lin-Manuel_Miranda.ogv/Hamilton_Mixtape_%2812_May_2009_live_at_the_White_House%29_Lin-Manuel_Miranda.ogv",
                  @"resolution": @(720)},
                @{@"title": @"Alaskan Huskies",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/0/08/Alaskan_Huskies_-_Sled_Dogs_-_Ivalo_2013.ogv/Alaskan_Huskies_-_Sled_Dogs_-_Ivalo_2013.ogv"},

                // Blender open movies
                @{@"title": @"Sintel",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/f/f1/Sintel_movie_4K.webm/Sintel_movie_4K.webm"},
                @{@"title": @"Tears of Steel",
                  //@"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/a/af/Tears_of_Steel_4K.webm/Tears_of_Steel_4K.webm"}, // bad color conversion
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/c/cb/Tears_of_Steel_1080p.webm/Tears_of_Steel_1080p.webm"},
                @{@"title": @"Big Buck Bunny (60fps)",
                  @"URL": @"https://upload.wikimedia.org/wikipedia/commons/transcoded/c/c0/Big_Buck_Bunny_4K.webm/Big_Buck_Bunny_4K.webm"},

                // Short tests
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
        if (!source[@"audioOnly"]) {
            str = [NSString stringWithFormat:@"%@.%@", str, target];
        }

        self.player.sourceURL = [NSURL URLWithString:str];
        // @todo separate load & play...
        //[self.player play];
    }
}

- (IBAction)selectFormat:(id)sender {
    lastPosition = self.player.playbackPosition;

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
    lastPosition = self.player.playbackPosition;
    
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

- (void)ogvPlayerDidLoadMetadata:(OGVPlayerView *)sender
{
    if (lastPosition > 0) {
        [self.player seek:lastPosition];
        lastPosition = 0;
    }

    [self.player play];
}

- (void)ogvPlayerDidEnd:(OGVPlayerView *)sender
{
    lastPosition = 0;

    NSInteger nextSource = selectedSource + 1;
    if (nextSource < [sources count]) {
        [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForItem:nextSource inSection:0]
                                    animated:YES
                              scrollPosition:UITableViewScrollPositionNone];
        [self selectSource:nextSource];
    }
}

@end
