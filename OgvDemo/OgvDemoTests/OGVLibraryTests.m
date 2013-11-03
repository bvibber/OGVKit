//
//  OgvDemoTests.m
//  OgvDemoTests
//
//  Created by Brion on 11/2/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import <XCTest/XCTest.h>

#define OV_EXCLUDE_STATIC_CALLBACKS
#include <ogg/ogg.h>
#include <vorbis/vorbisfile.h>
#include <theora/theora.h>

@interface OGVLibraryTests : XCTestCase

@end

@implementation OGVLibraryTests

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

- (void)testOgg
{
    ogg_sync_state syncState;

    int ret = ogg_sync_init(&syncState);
    XCTAssertEqual(ret, 0, @"ogg_sync_init links, runs and returns 0");

    ret = ogg_sync_clear(&syncState);
    XCTAssertEqual(ret, 0, @"ogg_sync_clear links, runs and returns 0");
}

- (void)testVorbis
{
    vorbis_info info;
    vorbis_info_init(&info);
    vorbis_info_clear(&info);
    XCTAssert(YES, @"vorbis_info_init/clear link and run");
}

- (void)testTheora
{
    theora_info info;
    theora_info_init(&info);
    theora_info_clear(&info);
    XCTAssert(YES, @"theora_info_init/clear link and run");
}
@end
