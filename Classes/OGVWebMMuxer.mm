//
//  OGVWebmMuxer.mm
//  OGVKit
//
//  Copyright (c) 2016 Brion Vibber. All rights reserved.
//

#include "OGVKit.h"
#include "OGVWebMMuxer.h"

#include "WebM/mkvmuxer/mkvmuxer.h"
#include "WebM/mkvmuxer/mkvmuxertypes.h"
#include "WebM/mkvmuxer/mkvwriter.h"

@interface OGVWebMMuxer (Private)
@property OGVAudioFormat *audioFormat;
@property OGVVideoFormat *videoFormat;
@property BOOL hasVideo;
@property BOOL hasAudio;
@end

class OGVKitMkvWriter : public mkvmuxer::IMkvWriter {
public:
    OGVOutputStream *stream;

    OGVKitMkvWriter() {
        
    }

    explicit OGVKitMkvWriter(OGVOutputStream *_stream) {
        this->stream = _stream;
    }

    virtual ~OGVKitMkvWriter() {
        this->stream = nil;
    }

    // Writes out |len| bytes of |buf|. Returns 0 on success.
    virtual mkvmuxer::int32 Write(const void* buf, mkvmuxer::uint32 len) override {
        @try {
            NSData *data = [NSData dataWithBytesNoCopy:(void * _Nonnull)buf length:len];
            [stream write:data];
            return 0;
        } @catch (NSException *e) {
            return -1;
        }
    }
    
    // Returns the offset of the output position from the beginning of the
    // output.
    virtual mkvmuxer::int64 Position() const override {
        return stream.offset;
    }
    
    // Set the current File position. Returns 0 on success.
    virtual mkvmuxer::int32 Position(mkvmuxer::int64 position) override {
        @try {
            [stream seek:position];
            return 0;
        } @catch (NSException *e) {
            return -1;
        }
    }
    
    // Returns true if the writer is seekable.
    virtual bool Seekable() const override {
        return stream.seekable;
    }
    
    // Element start notification. Called whenever an element identifier is about
    // to be written to the stream. |element_id| is the element identifier, and
    // |position| is the location in the WebM stream where the first octet of the
    // element identifier will be written.
    // Note: the |MkvId| enumeration in webmids.hpp defines element values.
    virtual void ElementStartNotify(mkvmuxer::uint64 element_id, mkvmuxer::int64 position) override {
        // no-op
    }

};

@implementation OGVWebMMuxer
{
    OGVOutputStream *outputStream;
    OGVAudioFormat *audioFormat;
    OGVVideoFormat *videoFormat;
    NSArray *audioHeaders;
    NSArray *videoHeaders;
    
    OGVKitMkvWriter *writer;
    mkvmuxer::Segment *segment;
    uint64_t videoTrackId;
    uint64_t audioTrackId;
}

-(void)dealloc
{
    if (segment) {
        delete segment;
    }
    if (writer) {
        delete writer;
    }
}

-(void)openOutputStream:(OGVOutputStream *)_outputStream
{
    outputStream = _outputStream;

    writer = new OGVKitMkvWriter(outputStream);
    segment = new mkvmuxer::Segment();
    segment->Init(writer);
}

-(void)addVideoTrack:(OGVVideoEncoder *)videoEncoder
{
    OGVVideoFormat *videoFormat = videoEncoder.format;

    videoTrackId = segment->AddVideoTrack(videoFormat.frameWidth,
                                          videoFormat.frameHeight,
                                          0);
    auto videoTrack = static_cast<mkvmuxer::VideoTrack*>(segment->GetTrackByNumber(videoTrackId));
    if ([videoEncoder.codec isEqualToString:@"vp8"]) {
        videoTrack->set_codec_id("V_VP8");
    } else {
        [NSException raise:@"OGVWebMMuxerException"
                    format:@"unexpected video type"];
    }

    videoTrack->set_display_width(videoFormat.pictureWidth);
    videoTrack->set_display_height(videoFormat.pictureHeight);
    videoTrack->set_crop_left(videoFormat.pictureOffsetX);
    videoTrack->set_crop_top(videoFormat.pictureOffsetY);
    videoTrack->set_crop_right(videoFormat.frameWidth - videoFormat.pictureOffsetX - videoFormat.pictureWidth);
    videoTrack->set_crop_bottom(videoFormat.frameHeight - videoFormat.pictureOffsetY - videoFormat.pictureHeight);
    
    mkvmuxer::Cues *const cues = segment->GetCues();
    cues->set_output_block_number(true);
    segment->CuesTrack(videoTrackId);
}

-(void)addAudioTrack:(OGVAudioEncoder *)audioEncoder
{
    audioTrackId = segment->AddAudioTrack(audioEncoder.format.sampleRate,
                                          audioEncoder.format.channels,
                                          0);
    auto audioTrack = static_cast<mkvmuxer::AudioTrack*>(segment->GetTrackByNumber(audioTrackId));
    if ([audioEncoder.codec isEqualToString:@"vorbis"]) {
        audioTrack->set_codec_id("A_VORBIS");
    } else if ([audioEncoder.codec isEqualToString:@"opus"]) {
        audioTrack->set_codec_id("A_OPUS");
    } else {
        [NSException raise:@"OGVWebMMuxerException"
                    format:@"unexpected audio type"];
    }

    NSData *codecPrivate = [self encodeCodecPrivate:audioEncoder.headers];
    audioTrack->SetCodecPrivate((const uint8_t *)codecPrivate.bytes, codecPrivate.length);
}

// https://matroska.org/technical/specs/index.html#lacing
-(NSData *)encodeCodecPrivate:(NSArray *)headers
{
    if (!headers.count) {
        [NSException raise:@"OGVWebMMuxerException"
                    format:@"missing codec private headers"];
    }
    size_t nbytes = 1;
    for (OGVPacket *packet in headers) {
        size_t packetLength = packet.data.length;
        while (packetLength >= 255) {
            nbytes++;
            packetLength -= 255;
        }
        nbytes++;
        nbytes += packet.data.length;
    }

    NSMutableData *codecPrivate = [[NSMutableData alloc] initWithLength:nbytes];
    uint8_t *bytes = (uint8_t *)codecPrivate.bytes;
    *bytes++ = headers.count - 1;
    for (OGVPacket *packet in headers) {
        size_t packetLength = packet.data.length;
        while (packetLength >= 255) {
            *bytes++ = 255;
            packetLength -= 255;
        }
        *bytes++ = packetLength;
    }
    for (OGVPacket *packet in headers) {
        memcpy((void *)packet.data.bytes, (void *)bytes, packet.data.length);
        bytes += packet.data.length;
    }

    return codecPrivate;
}

-(void)appendAudioPacket:(OGVPacket *)packet
{
    mkvmuxer::Frame frame;
    if (!frame.Init((const uint8_t *)packet.data.bytes, packet.data.length)) {
        [NSException raise:@"OGVWebMMuxerException"
                    format:@"failed to init webm audio frame"];
    }
    frame.set_track_number(audioTrackId);
    frame.set_timestamp(packet.timestamp * NSEC_PER_SEC);
    //frame.set_duration(packet.duration * NSEC_PER_SEC);
    frame.set_is_key(packet.keyframe);
    
    NSLog(@"appending audio %f %f %d", packet.timestamp, packet.duration, (int)packet.keyframe);
    if (!segment->AddGenericFrame(&frame)) {
        [NSException raise:@"OGVWebMMuxerException"
                    format:@"failed to add webm audio frame"];
    }
}

-(void)appendVideoPacket:(OGVPacket *)packet
{
    mkvmuxer::Frame frame;
    if (!frame.Init((const uint8_t *)packet.data.bytes, packet.data.length)) {
        [NSException raise:@"OGVWebMMuxerException"
                    format:@"failed to init webm frame"];
    }
    frame.set_track_number(videoTrackId);
    frame.set_timestamp(packet.timestamp * NSEC_PER_SEC);
    //frame.set_duration(packet.duration * NSEC_PER_SEC);
    frame.set_is_key(packet.keyframe);
    
    NSLog(@"appending video %f %f %d", packet.timestamp, packet.duration, (int)packet.keyframe);
    if (!segment->AddGenericFrame(&frame)) {
        [NSException raise:@"OGVWebMMuxerException"
                    format:@"failed to add webm frame"];
    }
}

-(void)close
{
    if (!segment->Finalize()) {
        [NSException raise:@"OGVWebMMuxerException"
                    format:@"failed to finalize webm output"];
    }
    [outputStream close];
}

@end
