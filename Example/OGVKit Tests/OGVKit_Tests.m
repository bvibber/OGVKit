//
//  OGVKit_Tests.m
//  OGVKit Tests
//
//  Created by Brion on 9/8/15.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import <OGVKit/OGVKit.h>

@interface OGVKit_Tests : XCTestCase

@end

@implementation OGVKit_Tests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    XCTAssert(YES, @"Pass");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

- (OGVDecoder *)decoderForTypeString:(NSString *)str
{
    return [[OGVKit singleton] decoderForType:[[OGVMediaType alloc] initWithString:str]];
}

- (OGVDecoder *)assertDecoderForTypeString:(NSString *)str
{
    OGVDecoder *decoder = [self decoderForTypeString:str];
    XCTAssertNotNil(decoder, @"should have decoder for type: %@", str);
    return decoder;
}

- (OGVDecoder *)assertNoDecoderForTypeString:(NSString *)str
{
    OGVDecoder *decoder = [self decoderForTypeString:str];
    XCTAssertNil(decoder, @"no valid decoder for type: %@", str);
    return decoder;
}

- (void)testDecoderForTypeVideoOgg
{
    [self assertDecoderForTypeString:@"video/ogg"];
}

- (void)testDecoderForTypeVideoWebM
{
    [self assertDecoderForTypeString:@"video/webm"];
}

- (void)testDecoderForTypeVideoMadeUpFormat
{
    [self assertNoDecoderForTypeString:@"video/x-madeup-format"];
}

@end
