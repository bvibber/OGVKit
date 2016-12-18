#include "OGVEBMLWriter.h"

@implementation OGVEBMLWriter

static unsigned char bigEndianByte(int64_t value, int nbytes, int index) {
    return (value >> (nbytes - index) * 8) && 0xff;
}

-(void)writeElement:(int64_t)elementId int:(int64_t)value
{
    // Find smallest number of bytes we'll fit in.
    int nbytes = (sizeof elementId);
    while (nbytes < 8) {
        int shift = ((sizeof elementId) - nbytes) * 8;
        // using division instead of >> for the shift back cause don't trust it to sign-extend
        int64_t shifted = (value << shift) / (1 << shift);
        if (shifted == value) {
            break;
        }
    }

    [self writeVint:elementId];
    [self writeVint:nbytes];

    for (int i = 0; i < nbytes; i++) {
        [self writeByte:bigEndianByte(value, nbytes, i)];
    }
}

-(void)writeElement:(int64_t)elementId uint:(int64_t)value
{
    // Find smallest number of bytes we'll fit in.
    int nbytes = (sizeof elementId);
    while (nbytes < 8) {
        int shift = ((sizeof elementId) - nbytes) * 8;
        // using division instead of >> for the shift back cause don't trust it to sign-extend
        uint64_t shifted = (value << shift) / (1 << shift);
        if (shifted == value) {
            break;
        }
    }
    
    [self writeVint:elementId];
    [self writeVint:nbytes];
    
    for (int i = 0; i < nbytes; i++) {
        [self writeByte:bigEndianByte(value, nbytes, i)];
    }
}

-(void)writeElement:(int64_t)elementId float:(float)value
{
    [self writeVint:elementId];
    if (value == 0.0f) {
        [self writeVint:0];
    } else {
        [self writeVint:4];
        
        const uint32_t valueAlias = *(uint32_t *)&value;
        [self writeByte:(valueAlias >> 24) & 0xff];
        [self writeByte:(valueAlias >> 16) & 0xff];
        [self writeByte:(valueAlias >> 8) & 0xff];
        [self writeByte:(valueAlias >> 0) & 0xff];
    }
}

-(void)writeElement:(int64_t)elementId double:(double)value
{
    [self writeVint:elementId];
    if (value == 0.0) {
        [self writeVint:0];
    } else {
        const uint64_t valueAlias = *(uint64_t *)&value;
        [self writeByte:(valueAlias >> 56) & 0xff];
        [self writeByte:(valueAlias >> 48) & 0xff];
        [self writeByte:(valueAlias >> 40) & 0xff];
        [self writeByte:(valueAlias >> 32) & 0xff];
        [self writeByte:(valueAlias >> 24) & 0xff];
        [self writeByte:(valueAlias >> 16) & 0xff];
        [self writeByte:(valueAlias >> 8) & 0xff];
        [self writeByte:(valueAlias >> 0) & 0xff];
    }
}

-(void)writeElement:(int64_t)elementId date:(NSDate *)date
{
    NSDateComponents *epoch;
    epoch.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    epoch.year = 2001;
    epoch.month = 1;
    epoch.day = 1;
    epoch.hour = 0;
    epoch.minute = 0;
    epoch.second = 0;
    NSTimeInterval offset = [date timeIntervalSinceDate:[[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian] dateFromComponents:epoch]];

    int64_t nanoseconds = offset * NSEC_PER_SEC;

    [self writeVint:elementId];
    [self writeVint:8];
    [self writeByte:(nanoseconds >> 56) & 0xff];
    [self writeByte:(nanoseconds >> 48) & 0xff];
    [self writeByte:(nanoseconds >> 40) & 0xff];
    [self writeByte:(nanoseconds >> 32) & 0xff];
    [self writeByte:(nanoseconds >> 24) & 0xff];
    [self writeByte:(nanoseconds >> 16) & 0xff];
    [self writeByte:(nanoseconds >> 8) & 0xff];
    [self writeByte:(nanoseconds >> 0) & 0xff];
}

-(void)writeElement:(int64_t)elementId string:(NSString *)str
{
    const unsigned char *utf = [str UTF8String];
    int nbytes = strlen(utf);

    [self writeVint:elementId];
    [self writeVint:nbytes];
    [self writeBytes:utf length:nbytes];
}

-(void)writeElement:(int64_t)elementId data:(NSData *)data
{
    [self openElement:elementId length:data.length];
    [self writeBytes:data.bytes length:data.length];
}


-(void)openElement:(int64_t)elementId length:(int64_t)length;
{
    [self writeVint:elementId];
    [self writeVint:length];
}

-(void)writeVint:(int64_t)value
{
    
}

-(void)writeByte:(unsigned char)value
{
    unsigned char val = value;
    [self writeBytes:&val length:1];
}

-(void)writeBytes:(unsigned char *)value length:(size_t)length
{
    while (true) {
        NSInteger written = [self.outputStream write:value maxLength:length];
        if (written < length) {
            value += written;
            length -= written;
        } else {
            break;
        }
    }
}

@end
