//
//  OGVLogger.m
//  OGVKit
//
//  Created by Brion on 1/16/2018
//  Copyright (c) 2018 Brion Vibber. All rights reserved.
//

#include "OGVLogger.h"

static const char *levelNames[] = {
    "DEBUG",
    "WARN",
    "ERROR",
    "FATAL",
    NULL
};

@implementation OGVLogger

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.level = OGVLogLevelError;
    }
    return self;
}

- (void)debugWithFormat:(NSString *)formatString, ...
{
    va_list args;
    va_start(args, formatString);
    [self logWithLevel:OGVLogLevelDebug format:formatString arguments:args];
    va_end(args);
}

- (void)warnWithFormat:(NSString *)formatString, ...
{
    va_list args;
    va_start(args, formatString);
    [self logWithLevel:OGVLogLevelWarning format:formatString arguments:args];
    va_end(args);
}

- (void)errorWithFormat:(NSString *)formatString, ...
{
    va_list args;
    va_start(args, formatString);
    [self logWithLevel:OGVLogLevelError format:formatString arguments:args];
    va_end(args);
}

- (void)fatalWithFormat:(NSString *)formatString, ...
{
    va_list args;
    va_start(args, formatString);
    [self logWithLevel:OGVLogLevelFatal format:formatString arguments:args];
    va_end(args);
}

- (void)logWithLevel:(OGVLogLevel)level format:(NSString *)formatString arguments:(va_list)args
{
    if (self.level <= level) {
        [self logWithLevel:level
                   message:[[NSString alloc] initWithFormat:formatString
                                                  arguments:args]];
    }
}

- (void)logWithLevel:(OGVLogLevel)level message:(NSString *)message
{
    NSLog(@"[%s] %@", levelNames[level], message);
}

@end

