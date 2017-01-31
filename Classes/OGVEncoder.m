#import "OGVKit.h"

@implementation OGVEncoder
{
    OGVMediaType *mediaType;
    OGVMuxer *muxer;
    OGVVideoEncoder *videoEncoder;
    OGVAudioEncoder *audioEncoder;
}

-(instancetype)initWithMediaType:(OGVMediaType *)mediaType
{
    self = [self init];
    if (self) {
        mediaType = mediaType;
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
    [muxer addVideoTrackFormat:videoFormat];
    videoEncoder = [[OGVKit singleton] videoEncoderForType:mediaType
                                                         format:videoFormat
                                                        options:options];
}


-(void)addAudioTrackFormat:(OGVAudioFormat *)audioFormat
                   options:(NSDictionary *)options
{
    if (audioEncoder) {
        [NSException raise:@"OGVEncoderException"
                    format:@"can only handle one audio track"];
    }
    [muxer addAudioTrackFormat:audioFormat];
    audioEncoder = [[OGVKit singleton] audioEncoderForType:mediaType
                                                         format:audioFormat
                                                        options:options];
}

-(void)openOutputStream:(OGVOutputStream *)outputStream
{
    [muxer openOutputStream:outputStream];
}

-(void)encodeAudio:(OGVAudioBuffer *)buffer
{
    [audioEncoder encodeAudio:buffer];
    [self writeAudioPackets];
}

-(void)encodeFrame:(OGVVideoBuffer *)buffer
{
    [videoEncoder encodeFrame:buffer];
    [self writeVideoPackets];
}

-(void)close
{
    [videoEncoder close];
    [self writeVideoPackets];

    [audioEncoder close];
    [self writeAudioPackets];

    [muxer close];
}

#pragma mark - private methods

-(void)writeVideoPackets
{
    while ([videoEncoder.packets peek]) {
        [muxer appendAudioPacket:[videoEncoder.packets dequeue]];
    }
}

-(void)writeAudioPackets
{
    while ([audioEncoder.packets peek]) {
        [muxer appendAudioPacket:[audioEncoder.packets dequeue]];
    }
}

@end
