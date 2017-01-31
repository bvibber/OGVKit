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

    explicit OGVKitMkvWriter(OGVOutputStream *stream) {
        this->stream = stream;
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
    OGVKitMkvWriter *writer;
    mkvmuxer::Segment *segment;
    mkvmuxer::VideoTrack *videoTrack;
    mkvmuxer::AudioTrack *audioTrack;
}

-(instancetype)initWithOutputStream:(OGVOutputStream *)outputStream
                        audioFormat:(OGVAudioFormat *)audioFormat
                        videoFormat:(OGVVideoFormat *)videoFormat
{
    self = [super initWithOutputStream:outputStream audioFormat:audioFormat videoFormat:videoFormat];
    if (self) {
        // @fixme init writer
        writer = new OGVKitMkvWriter(self.outputStream);
        segment = new mkvmuxer::Segment();
        segment->Init(writer);
    }
    return self;
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

-(void)writeHeaders
{
    // set segment info?
    
    uint64_t vid_track = segment->AddVideoTrack(self.videoFormat.frameWidth,
                                                self.videoFormat.frameHeight,
                                                0);
    videoTrack = static_cast<mkvmuxer::VideoTrack*>(segment->GetTrackByNumber(vid_track));
    videoTrack->set_codec_id("VP80");
    videoTrack->set_display_width(self.videoFormat.pictureWidth);
    videoTrack->set_display_height(self.videoFormat.pictureHeight);
    videoTrack->set_crop_left(self.videoFormat.pictureOffsetX);
    videoTrack->set_crop_top(self.videoFormat.pictureOffsetY);
    videoTrack->set_crop_right(self.videoFormat.frameWidth - self.videoFormat.pictureOffsetX - self.videoFormat.pictureWidth);
    videoTrack->set_crop_bottom(self.videoFormat.frameHeight - self.videoFormat.pictureOffsetY - self.videoFormat.pictureHeight);
    
    mkvmuxer::Cues *const cues = segment->GetCues();
    cues->set_output_block_number(true);
    segment->CuesTrack(vid_track);
}


-(void)appendAudioPacket:(OGVPacket *)packet
{
    NSLog(@"encoding not implemented");
}

-(void)appendVideoPacket:(OGVPacket *)packet
{
    NSLog(@"encoding not implemented");
    mkvmuxer::Frame frame;
    if (!frame.Init((const uint8_t *)packet.data.bytes, packet.data.length)) {
        [NSException raise:@"OGVWebMMuxerException"
                    format:@"failed to init webm frame"];
    }
    frame.set_timestamp(packet.timestamp * NSEC_PER_SEC);
    
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
    [self.outputStream close];
}

@end
