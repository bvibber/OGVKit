//
//  OGVHTTPContentRange.h
//  OGVKit
//
//  Created by Brion on 6/21/2015.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

@interface OGVHTTPContentRange : NSObject

@property (readonly) int64_t start;
@property (readonly) int64_t end;
@property (readonly) int64_t total;
@property (readonly) BOOL valid;

- (instancetype)initWithString:(NSString *)string;

@end
