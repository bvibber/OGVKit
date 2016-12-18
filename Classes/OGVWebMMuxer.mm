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

@implementation OGVWebMMuxer
{
    mkvmuxer::IMkvWriter *writer;
    mkvmuxer::Segment *segment;
    mkvmuxer::VideoTrack *videoTrack;
    mkvmuxer::AudioTrack *audioTrack;
}

-(instancetype)init
{
    self = [super init];
    if (self) {
        // @fixme init writer
        segment = new mkvmuxer::Segment();
        segment->Init(writer);
    }
}

-(void)dealloc
{
    if (segment) {
        delete segment;
    }
    if (writer) {
        //delete writer;
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
}

@end
