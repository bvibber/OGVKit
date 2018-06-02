//
//  OGVFileOutputStream.m
//  OGVKit
//
//  Copyright (c) 2017 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

@implementation OGVFileOutputStream
{
    FILE *file;
}

-(instancetype)initWithPath:(NSString *)path
{
    self = [super init];
    if (self) {
        file = fopen([path UTF8String], "wb");
        if (!file) {
            [NSException raise:@"OGVFileOutputStreamException"
                        format:@"failed to open file %@", path];
        }
    }
    return self;
}

-(int64_t)offset
{
    return ftell(file);
}

-(BOOL)seekable
{
    return YES;
}

-(void)seek:(int64_t)pos
{
    fseeko(file, pos, SEEK_SET);
}

-(void)write:(NSData *)data
{
    fwrite(data.bytes, 1, data.length, file);
}

-(void)close
{
    fclose(file);
    file = NULL;
}

@end
