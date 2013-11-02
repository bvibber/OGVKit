//
//  OgvDemoTests.m
//  OgvDemoTests
//
//  Created by Brion on 11/2/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import <XCTest/XCTest.h>

#include <ogg/ogg.h>

@interface OgvDemoTests : XCTestCase

@end

@implementation OgvDemoTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample
{
    ogg_sync_state syncState;
    int ret = ogg_sync_init(&syncState);
    XCTAssertEqual(ret, 0, @"ogg_sync_init returns 0");
}

@end
