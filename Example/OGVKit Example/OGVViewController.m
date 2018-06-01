//
//  OGVViewController.m
//  OgvKit
//
//  Created by Brion Vibber on 02/08/2015.
//  Copyright (c) 2014-2015 Brion Vibber. All rights reserved.
//

#import "OGVViewController.h"

#import "OGVExampleItem.h"
#import "OGVLinkedExampleItem.h"
#import "OGVCommonsExampleItem.h"
#import "OGVMediaExampleItem.h"

// Uncomment to run the '(local)' file tests via NSData buffer instead of filesystem
//#define TEST_DATA_INPUT 1

@interface OGVViewController ()

@end

@implementation OGVViewController
{
    NSArray *sources;

    NSInteger selectedSource;
    OGVExampleItem *source;

    NSArray *formats;
    NSString *format;

    NSArray *resolutions;
    int resolution;

    BOOL firstTime;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    sources = @[
                [[OGVMediaExampleItem alloc] initWithTitle:@"Curiosity's Seven Minutes of Terror"
                                                  filename:@"Curiosity's Seven Minutes of Terror.ogv"
                                                resolution:720],
                [[OGVMediaExampleItem alloc] initWithTitle:@"RED 4K Video of Colorful Liquid in Space"
                                                  filename:@"RED 4K Video of Colorful Liquid in Space.webm"
                                                resolution:2160],
                [[OGVMediaExampleItem alloc] initWithTitle:@"International Space Station"
                                                  filename:@"Ultra High Definition Video from the International Space Station (Reel 1).webm"
                                                resolution:1440],
                [[OGVMediaExampleItem alloc] initWithTitle:@"Here's to Engineering"
                                                  filename:@"Here's to Engineering.webm"
                                                resolution:2160],

                [[OGVMediaExampleItem alloc] initWithTitle:@"Caminandes - Gran Dillama (animation)"
                                                  filename:@"Caminandes - Gran Dillama - Blender Foundation's new Open Movie.webm"
                                                resolution:1080],
                [[OGVMediaExampleItem alloc] initWithTitle:@"Glass Half (animation)"
                                                  filename:@"Glass Half - 3D animation with OpenGL cartoon rendering.webm"
                                                resolution:2160],
                [[OGVMediaExampleItem alloc] initWithTitle:@"Tears of Steel (sci-fi)"
                                                  filename:@"Tears of Steel in 4k - Official Blender Foundation release.webm"
                                                resolution:2160],

                [[OGVMediaExampleItem alloc] initWithTitle:@"Women in botany and Wikipedia"
                                                  filename:@"Women in botany and Wikipedia.webm"
                                                resolution:2160],
                [[OGVMediaExampleItem alloc] initWithTitle:@"Art and Feminism Wikipedia Edit-a-thon"
                                                  filename:@"Art and Feminism Wikipedia Edit-a-thon, February 1, 2014.webm"
                                                resolution:1080],
                [[OGVMediaExampleItem alloc] initWithTitle:@"Open Access: Empowering Discovery"
                                                  filename:@"How_Open_Access_Empowered_a_16-Year-Old_to_Make_Cancer_Breakthrough.ogv"
                                                resolution:1080],
                [[OGVMediaExampleItem alloc] initWithTitle:@"Knowledge for Everyone"
                                                  filename:@"Knowledge for Everyone (short cut).webm"
                                                resolution:1080],
                [[OGVMediaExampleItem alloc] initWithTitle:@"Share-a-Fact on Wikipedia Android app"
                                                  filename:@"Share-a-Fact on the Official Wikipedia Android app.webm"
                                                resolution:1080],
                [[OGVMediaExampleItem alloc] initWithTitle:@"The Impact Of Wikipedia"
                                                  filename:@"The Impact Of Wikipedia.webm"
                                                resolution:1080],
                [[OGVMediaExampleItem alloc] initWithTitle:@"WikiArabia tech meetup in Ramallah"
                                                  filename:@"WikiArabia tech meetup in Ramallah 2016.webm"
                                                resolution:1080],
                [[OGVMediaExampleItem alloc] initWithTitle:@"Wikipedia Edit 2015"
                                                  filename:@"Wikipedia Edit 2015.webm"
                                                resolution:1080],
                

                [[OGVMediaExampleItem alloc] initWithTitle:@"Wiki Makes Video (mixed 60fps)"
                                                  filename:@"Wiki Makes Video Intro 4 26.webm"
                                                resolution:720],
                [[OGVMediaExampleItem alloc] initWithTitle:@"Tawakkol Karman (mixed 50fps)"
                                                  filename:@"Tawakkol Karman (English).ogv"
                                                resolution:1080],
                [[OGVMediaExampleItem alloc] initWithTitle:@"Eisbach surfen (high motion)"
                                                 filename:@"Eisbach surfen v1.ogv"
                                                resolution:720],

                [[OGVMediaExampleItem alloc] initWithTitle:@"FEZ trial gameplay HD.webm"
                                                  filename:@"FEZ trial gameplay HD.webm"
                                                resolution:720],
                [[OGVMediaExampleItem alloc] initWithTitle:@"Red-tailed Hawk (60fps)"
                                                  filename:@"Red-tailed Hawk Eating a Rodent 1080p 60fps.ogv"
                                                resolution:720],
                [[OGVMediaExampleItem alloc] initWithTitle:@"Snowdonia by drone"
                                                  filename:@"Snowdonia by drone.webm"
                                                resolution:1080],
                [[OGVMediaExampleItem alloc] initWithTitle:@"Stugl aerial (60fps, video only)"
                                                  filename:@"Stugl,aerial video.webm"
                                                resolution:1080],
                [[OGVMediaExampleItem alloc] initWithTitle:@"President Obama Sings (60fps)"
                                                  filename:@"President Obama Sings \"Sweet Home Chicago\".webm"
                                                resolution:720],
                [[OGVMediaExampleItem alloc] initWithTitle:@"White House Kitchen Garden (60fps mixed)"
                                                  filename:@"Inside the White House- The Kitchen Garden.webm"
                                                resolution:720],
                [[OGVMediaExampleItem alloc] initWithTitle:@"Job Simulator (60fps game engine)"
                                                  filename:@"Spectator Mode for Job Simulator - a new way to display social VR footage.webm"
                                                resolution:1080],
                [[OGVMediaExampleItem alloc] initWithTitle:@"Project CARS (60fps game engine)"
                                                  filename:@"Project CARS - Game of the Year Edition Launch Trailer.webm"
                                                resolution:1080],


                // Video-only tests
                [[OGVCommonsExampleItem alloc] initWithTitle:@"Myopa (video only)"
                                                    filename:@"Myopa_-_2015-05-02.webm"],

                // Audio-only tests
                [[OGVCommonsExampleItem alloc] initWithTitle:@"Bach C Major (audio)"
                                                    filename:@"Bach_C_Major_Prelude_Werckmeister.ogg"],
                [[OGVCommonsExampleItem alloc] initWithTitle:@"Arigato (short audio)"
                                                    filename:@"Ja-arigato.oga"],
                [[OGVCommonsExampleItem alloc] initWithTitle:@"O du froehliche (Opus audio)"
                                                    filename:@"O du froehliche - GL 238 audio.opus"],
                
                // Local test files
                [[OGVLinkedExampleItem alloc] initWithTitle:@"Res switching (local)"
                                                        URL:[[NSBundle mainBundle] URLForResource:@"vp8-res-switch"
                                                                                    withExtension:@"webm"]],

                [[OGVLinkedExampleItem alloc] initWithTitle:@"Bunny low-res intro (local)"
                                                        URL:[[NSBundle mainBundle] URLForResource:@"bunny"
                                                                                    withExtension:@"ogv"]],

                [[OGVLinkedExampleItem alloc] initWithTitle:@"Bunny low-res VP9 Vorbis (local)"
                                                        URL:[[NSBundle mainBundle] URLForResource:@"bunny"
                                                                                    withExtension:@"webm"]],
                
                [[OGVLinkedExampleItem alloc] initWithTitle:@"Bunny low-res VP9 OPUS (local)"
                                                        URL:[[NSBundle mainBundle] URLForResource:@"bunny_opus_vp9"
                                                                                    withExtension:@"webm"]],
                
                [[OGVLinkedExampleItem alloc] initWithTitle:@"Bunny low-res VP8 OPUS (local)"
                                                        URL:[[NSBundle mainBundle] URLForResource:@"bunny_opus_vp8"
                                                                                    withExtension:@"webm"]],


                [[OGVLinkedExampleItem alloc] initWithTitle:@"Kitty cat MP4 (local)"
                                                        URL:[[NSBundle mainBundle] URLForResource:@"kitty-short"
                                                                                    withExtension:@"mp4"]],

                [[OGVLinkedExampleItem alloc] initWithTitle:@"Hacking 4:2:0 (local)"
                                                        URL:[[NSBundle mainBundle] URLForResource:@"hacking-420"
                                                                                    withExtension:@"ogv"]],

                [[OGVLinkedExampleItem alloc] initWithTitle:@"Hacking 4:2:2 (local)"
                                                        URL:[[NSBundle mainBundle] URLForResource:@"hacking-422"
                                                                                    withExtension:@"ogv"]],

                [[OGVLinkedExampleItem alloc] initWithTitle:@"Hacking 4:4:4 (local)"
                                                        URL:[[NSBundle mainBundle] URLForResource:@"hacking-444"
                                                                                    withExtension:@"ogv"]]];

    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"generic"];
    
    self.player.delegate = self;

    format = @"webm";
    resolution = 360;
    firstTime = YES;
    [self selectSource:0];
}

- (void)selectSource:(NSInteger)index
{
    selectedSource = index;
    if (selectedSource >= 0) {
        source = sources[index];

        [self updateFormats];
        [self updateResolutions];

        NSURL *url;
        if ([resolutions count]) {
            url = [source URLforVideoFormat:format resolution:resolution];
        } else {
            url = [source URLforAudioFormat:format];
        }

#ifdef TEST_DATA_INPUT
        if (url.isFileURL) {
            NSData *data = [NSData dataWithContentsOfURL:url];
            NSLog(@"testing data with %d bytes", (int)data.length);
            self.player.inputStream = [OGVInputStream inputStreamWithData:data];
        } else {
            self.player.sourceURL = url;
        }
#else
        self.player.sourceURL = url;
#endif

        // @todo separate load & play...
        //[self.player play];
    }
}

- (IBAction)selectFormat:(id)sender {
    source.playbackPosition = self.player.playbackPosition;

    format = formats[self.formatSelector.selectedSegmentIndex];
    [self updateFormats];
    [self updateResolutions];
    [self selectSource:selectedSource];
}

- (void)updateFormats
{
    formats = [source formats];
    if (![formats containsObject:format]) {
        format = formats[0];
        if ([formats containsObject:@"ogg"]) {
            // prefer ogg over mp3
            format = @"ogg";
        }
        if ([formats containsObject:@"opus"]) {
            // prefer opus over ogg
            format = @"opus";
        }
        if ([formats containsObject:@"webm"]) {
            // prefer webm over ogv
            format = @"webm";
        }
    }
    
    [self.formatSelector removeAllSegments];
    for (int i = 0; i < [formats count]; i++) {
        NSString *title = formats[i];
        [self.formatSelector insertSegmentWithTitle:title
                                                atIndex:i
                                               animated:NO];
        if ([format isEqualToString:formats[i]]) {
            self.formatSelector.selectedSegmentIndex = i;
        }
    }
}

- (void)updateResolutions
{
    resolutions = [source resolutionsForFormat:format];

    int minRes = 0, maxRes = 0;
    if ([resolutions count]) {
        minRes = [resolutions[0] intValue];
        maxRes = [resolutions[[resolutions count] - 1] intValue];
        resolution = MAX(resolution, minRes);
        resolution = MIN(resolution, maxRes);

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
    } else {
        [self.resolutionSelector removeAllSegments];
        [self.resolutionSelector insertSegmentWithTitle:@"audio"
                                                atIndex:0
                                               animated:NO];
    }
}

- (IBAction)resolutionSelected:(id)sender {
    source.playbackPosition = self.player.playbackPosition;
    
    if ([resolutions count]) {
        resolution = [resolutions[self.resolutionSelector.selectedSegmentIndex] intValue];
    }

    [self selectSource:selectedSource];
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
    OGVExampleItem *item = sources[indexPath.item];
    cell.textLabel.text = item.title;
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
    if (source) {
        source.playbackPosition = self.player.playbackPosition;
    }
    [self selectSource:indexPath.item];
}

#pragma mark - OGVPlayerDelegate methods

- (void)ogvPlayerDidLoadMetadata:(OGVPlayerView *)sender
{
    if (firstTime) {
        // don't autoplay on app launch, it's annoying!
        firstTime = NO;
    } else {
        if (source.playbackPosition > 0) {
            [self.player seek:source.playbackPosition];
        }

        [self.player play];
    }
}

- (void)ogvPlayerDidEnd:(OGVPlayerView *)sender
{
    source.playbackPosition = 0;
    
    // temp: do nothing
    /*
    NSInteger nextSource = selectedSource + 1;
    if (nextSource < [sources count]) {
        [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForItem:nextSource inSection:0]
                                    animated:YES
                              scrollPosition:UITableViewScrollPositionNone];
        [self selectSource:nextSource];
    }
    */
}

@end
