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
                // Wikipedia stuff
                [[OGVCommonsExampleItem alloc] initWithTitle:@"Wikipedia VisualEditor"
                                                    filename:@"Sneak Preview - Wikipedia VisualEditor.webm"],
                [[OGVCommonsExampleItem alloc] initWithTitle:@"¿Qué es Wikipedia?"
                                                    filename:@"¿Qué es Wikipedia?.ogv"],
                [[OGVCommonsExampleItem alloc] initWithTitle:@"Wikipedia Edit 2015"
                                                    filename:@"Wikipedia Edit 2015.webm"],

                // Third-party stuff
                [[OGVCommonsExampleItem alloc] initWithTitle:@"Open Access: Empowering Discovery"
                                                    filename:@"How_Open_Access_Empowered_a_16-Year-Old_to_Make_Cancer_Breakthrough.ogv"],
                [[OGVCommonsExampleItem alloc] initWithTitle:@"Curiosity's Seven Minutes of Terror"
                                                    filename:@"Curiosity's Seven Minutes of Terror.ogv"],
                [[OGVCommonsExampleItem alloc] initWithTitle:@"Alaskan Huskies (heavy motion)"
                                                    filename:@"Alaskan_Huskies_-_Sled_Dogs_-_Ivalo_2013.ogv"],
                [[OGVCommonsExampleItem alloc] initWithTitle:@"International Space Station"
                                                    filename:@"Ultra High Definition Video from the International Space Station (Reel 1).webm"],

                // Blender open movies
                [[OGVCommonsExampleItem alloc] initWithTitle:@"Tears of Steel (sci-fi)"
                                                    filename:@"Tears_of_Steel_1080p.webm"],
                [[OGVCommonsExampleItem alloc] initWithTitle:@"Sintel (animation)"
                                                    filename:@"Sintel_movie_4K.webm"],
                [[OGVCommonsExampleItem alloc] initWithTitle:@"Caminandes - Llama Drama (animation)"
                                                    filename:@"Caminandes- Llama Drama - Short Movie.ogv"],
                [[OGVCommonsExampleItem alloc] initWithTitle:@"Caminandes - Gran Dillama (animation)"
                                                    filename:@"Caminandes - Gran Dillama - Blender Foundation's new Open Movie.webm"],

                // High frame rate
                [[OGVCommonsExampleItem alloc] initWithTitle:@"Big Buck Bunny (60fps animation)"
                                                    filename:@"Big_Buck_Bunny_4K.webm"],
                [[OGVCommonsExampleItem alloc] initWithTitle:@"Wiki Makes Video (60fps)"
                                                    filename:@"Wiki Makes Video Intro 4 26.webm"],
                [[OGVCommonsExampleItem alloc] initWithTitle:@"London apartment (60fps game engine)"
                                                    filename:@"UE4Arch.com - London apartment.webm"],
                [[OGVCommonsExampleItem alloc] initWithTitle:@"Job Simulator (60fps game engine)"
                                                    filename:@"Spectator Mode for Job Simulator - a new way to display social VR footage.webm"],

                // Video-only tests
                [[OGVCommonsExampleItem alloc] initWithTitle:@"Myopa (video only)"
                                                    filename:@"Myopa_-_2015-05-02.webm"],

                // Audio-only tests
                [[OGVCommonsExampleItem alloc] initWithTitle:@"Bach C Major (audio)"
                                                    filename:@"Bach_C_Major_Prelude_Werckmeister.ogg"],
                [[OGVCommonsExampleItem alloc] initWithTitle:@"Arigato (short audio)"
                                                    filename:@"Ja-arigato.oga"],
                
                // Local test files
                [[OGVLinkedExampleItem alloc] initWithTitle:@"Res switching (local)"
                                                        URL:[[NSBundle mainBundle] URLForResource:@"vp8-res-switch"
                                                                                    withExtension:@"webm"]],

                [[OGVLinkedExampleItem alloc] initWithTitle:@"Bunny low-res intro (local)"
                                                        URL:[[NSBundle mainBundle] URLForResource:@"bunny"
                                                                                    withExtension:@"ogv"]],

                [[OGVLinkedExampleItem alloc] initWithTitle:@"Bunny low-res VP9 (local)"
                                                        URL:[[NSBundle mainBundle] URLForResource:@"bunny"
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
        if ([formats containsObject:@"webm"]) {
            // prefer webm over ogv
            format = @"webm";
        } else {
            format = formats[0];
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

-(void)transcode
{
    OGVDecoder *decoder;
    
    [decoder process];

    OGVFileOutputStream *outputStream = [[OGVFileOutputStream alloc] initWithPath:@"/tmp/foo.webm"];

    OGVEncoder *encoder = [[OGVEncoder alloc] initWithMediaType:[[OGVMediaType alloc] initWithString:@"video/webm"]];
    [encoder addVideoTrackFormat:decoder.videoFormat
                         options:@{OGVVideoEncoderOptionsBitrateKey:@1000000,
                                   OGVVideoEncoderOptionsKeyframeIntervalKey: @150}];
    [encoder addAudioTrackFormat:decoder.audioFormat
                         options:@{OGVAudioEncoderOptionsBitrateKey:@128000}];
    [encoder openOutputStream:outputStream];

    while (true) {
        if (decoder.frameReady) {
            if ([decoder decodeFrame]) {
                [encoder encodeFrame:decoder.frameBuffer];
            }
        }
        if (decoder.audioReady) {
            if ([decoder decodeAudio]) {
                [encoder encodeAudio:decoder.audioBuffer];
            }
        }
        if (![decoder process]) {
            break;
        }
    }

    [encoder close];
}

@end
