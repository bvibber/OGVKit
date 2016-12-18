@interface OGVEBMLWriter : NSObject

@property (weak) NSOutputStream *outputStream;

-(void)writeElement:(int64_t)elementId;
-(void)writeElement:(int64_t)elementId int:(int64_t)value;
-(void)writeElement:(int64_t)elementId uint:(int64_t)value;
-(void)writeElement:(int64_t)elementId float:(float)value;
-(void)writeElement:(int64_t)elementId double:(double)value;
-(void)writeElement:(int64_t)elementId date:(NSDate *)date;
-(void)writeElement:(int64_t)elementId string:(NSString *)str;
-(void)writeElement:(int64_t)elementId data:(NSData *)data;

-(void)writeVint:(int64_t)value;
-(void)writeByte:(unsigned char)value;
-(void)writeBytes:(unsigned char *)value length:(size_t)length;

@end
