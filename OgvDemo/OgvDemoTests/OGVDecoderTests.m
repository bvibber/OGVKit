//
//  OGVDecoderTests.m
//  OgvDemo
//
//  Created by Brion on 11/2/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "OGVDecoder.h"

@interface OGVDecoderTests : XCTestCase

@end

@implementation OGVDecoderTests {
    OGVDecoder *decoder;
}

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
    decoder = [[OGVDecoder alloc] init];
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

- (void)testExample
{
    XCTAssertNotNil(decoder, @"Decoder gets allocated!");
}

@end
