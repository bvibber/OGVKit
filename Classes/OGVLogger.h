//
//  OGVLogger.h
//  OGVKit
//
//  Created by Brion on 1/16/2018
//  Copyright (c) 2018 Brion Vibber. All rights reserved.
//

typedef NS_ENUM(NSUInteger, OGVLogLevel) {
    OGVLogLevelDebug = 0,
    OGVLogLevelWarning = 1,
    OGVLogLevelError = 2,
    OGVLogLevelFatal = 3
};

@interface OGVLogger : NSObject

/**
 * Set to one of the OGVLogLevel constants for a minimum log level to output.
 */
@property OGVLogLevel level;

- (void)debugWithFormat:(NSString *)formatString, ...;
- (void)warnWithFormat:(NSString *)formatString, ...;
- (void)errorWithFormat:(NSString *)formatString, ...;
- (void)fatalWithFormat:(NSString *)formatString, ...;

/**
 * This is the one to override if you make a custom logger.
 */
- (void)logWithLevel:(OGVLogLevel)level message:(NSString *)message;

@end

