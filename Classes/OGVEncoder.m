#import "OGVKit.h"

@implementation OGVEncoder
{
    OGVMediaType *mediaType;
    OGVMuxer *muxer;
    OGVVideoEncoder *videoEncoder;
    OGVAudioEncoder *audioEncoder;
}

-(instancetype)initWithMediaType:(OGVMediaType *)_mediaType
{
    self = [super init];
    if (self) {
        mediaType = _mediaType;
        muxer = [[OGVKit singleton] muxerForType:mediaType];
    }
    return self;
}

-(void)addVideoTrackFormat:(OGVVideoFormat *)videoFormat
                   options:(NSDictionary *)options
{
    if (videoEncoder) {
        [NSException raise:@"OGVEncoderException"
                    format:@"can only handle one video track"];
    }
    videoEncoder = [[OGVKit singleton] videoEncoderForType:mediaType
                                                    format:videoFormat
                                                   options:options];
    [muxer addVideoTrack:videoEncoder];
}


-(void)addAudioTrackFormat:(OGVAudioFormat *)audioFormat
                   options:(NSDictionary *)options
{
    if (audioEncoder) {
        [NSException raise:@"OGVEncoderException"
                    format:@"can only handle one audio track"];
    }
    audioEncoder = [[OGVKit singleton] audioEncoderForType:mediaType
                                                    format:audioFormat
                                                   options:options];
    [muxer addAudioTrack:audioEncoder];
}

-(void)openOutputStream:(OGVOutputStream *)outputStream
{
    [muxer openOutputStream:outputStream];
}

-(void)encodeAudio:(OGVAudioBuffer *)buffer
{
    [audioEncoder encodeAudio:buffer];
    [self writePackets];
}

-(void)encodeFrame:(OGVVideoBuffer *)buffer
{
    [videoEncoder encodeFrame:buffer];
    [self writePackets];
}

-(void)close
{
    [videoEncoder close];
    [audioEncoder close];
    [self writeFinalPackets];

    [muxer close];
}

#pragma mark - private methods

// Write out any packets known to be in order
// Don't write out the last packets, since there might be stuff after
-(void)writePackets
{
    OGVPacket *videoPacket;
    OGVPacket *audioPacket;
    while ([audioEncoder.packets peek] && [videoEncoder.packets peek]) {
        while ([audioEncoder.packets peek] && ((OGVPacket *)[audioEncoder.packets peek]).timestamp <= ((OGVPacket *)[videoEncoder.packets peek]).timestamp) {
            [muxer appendAudioPacket:[audioEncoder.packets dequeue]];
        }
        while ([videoEncoder.packets peek] && ((OGVPacket *)[videoEncoder.packets peek]).timestamp <= ((OGVPacket *)[audioEncoder.packets peek]).timestamp) {
            [muxer appendVideoPacket:[videoEncoder.packets dequeue]];
        }
    }
}

-(void)writeFinalPackets
{
    [self writePackets];
    if ([audioEncoder.packets peek]) {
        [muxer appendAudioPacket:[audioEncoder.packets dequeue]];
    }
    if ([videoEncoder.packets peek]) {
        [muxer appendVideoPacket:[videoEncoder.packets dequeue]];
    }
}

@end
