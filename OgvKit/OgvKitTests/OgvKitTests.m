//
//  OgvKitTests.m
//  OgvKitTests
//
//  Created by Brion on 6/25/14.
//  Copyright (c) 2014 Brion Vibber. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "OgvKit.h"

@interface OgvKitTests : XCTestCase

@end

@implementation OgvKitTests

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

- (void)testClassesPresent
{
    XCTAssertNotNil([OGVAudioBuffer class], @"OGVAudioBuffer exists");
    XCTAssertNotNil([OGVFrameBuffer class], @"OGVFrameBuffer exists");
    XCTAssertNotNil([OGVDecoder class], @"OGVDecoder exists");
}

@end
