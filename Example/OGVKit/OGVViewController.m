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

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.player.sourceURL = [NSURL URLWithString:@"https://upload.wikimedia.org/wikipedia/commons/transcoded/b/bd/Toyama_Chih%C5%8D_Railway_Main_Line_2014-11-27_15-47-05_Higashi-Shinj%C5%8D_Station_-_Shinjo_Tanaka_Station.webm/Toyama_Chih%C5%8D_Railway_Main_Line_2014-11-27_15-47-05_Higashi-Shinj%C5%8D_Station_-_Shinjo_Tanaka_Station.webm.360p.ogv"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.player play];
    self.player.paused = NO;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.player.paused = YES;
}

@end
