//
//  OGVDecoderOgg.m
//  OGVKit
//
//  Created by Brion on 11/2/13.
//  Copyright (c) 2013 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"
#import "OGVDecoderOgg.h"

#define OV_EXCLUDE_STATIC_CALLBACKS
#include <ogg/ogg.h>

#ifdef OGVKIT_HAVE_DECODER_VORBIS
#include <vorbis/vorbisfile.h>
#endif

#ifdef OGVKIT_HAVE_DECODER_THEORA
#include <theora/theoradec.h>
#endif

static const NSUInteger kOGVDecoderReadBufferSize = 65536;

@implementation OGVDecoderOgg {
    /* Ogg and codec state for demux/decode */
    ogg_sync_state    oggSyncState;
    ogg_page          oggPage;
    
#ifdef OGVKIT_HAVE_DECODER_THEORA
    /* Video decode state */
    ogg_stream_state  theoraStreamState;
    th_info           theoraInfo;
    th_comment        theoraComment;
    th_setup_info    *theoraSetupInfo;
    th_dec_ctx       *theoraDecoderContext;
#endif
    
    int              theora_p;
    int              theora_processing_headers;
    
    /* single frame video buffering */
    int          videobuf_ready;
    ogg_int64_t  videobuf_granulepos;
    double       videobuf_time;
    OGVFrameBuffer *queuedFrame;
    
    int          audiobuf_ready;
    ogg_int64_t  audiobuf_granulepos; /* time position of last sample */
    
    int          raw;
    
    /* Audio decode state */
    int              vorbis_p;
    int              vorbis_processing_headers;
#ifdef OGVKIT_HAVE_DECODER_VORBIS
    ogg_stream_state vo;
    vorbis_info      vi;
    vorbis_dsp_state vd;
    vorbis_block     vb;
    vorbis_comment   vc;
#endif
    OGVAudioBuffer *queuedAudio;
    
    int          crop;
    
    ogg_packet oggPacket;
    ogg_packet theoraPacket;
    ogg_packet vorbisPacket;
    BOOL needData;
    
    int frames;
    
    enum AppState {
        STATE_BEGIN,
        STATE_HEADERS,
        STATE_DECODING
    } appState;
    int process_audio, process_video;
}


- (id)init
{
    self = [super init];
    if (self) {
        self.dataReady = NO;
        
        appState = STATE_BEGIN;
        
        /* start up Ogg stream synchronization layer */
        ogg_sync_init(&oggSyncState);
        
#ifdef OGVKIT_HAVE_DECODER_VORBIS
        /* init supporting Vorbis structures needed in header parsing */
        vorbis_info_init(&vi);
        vorbis_comment_init(&vc);
#endif

#ifdef OGVKIT_HAVE_DECODER_THEORA
        /* init supporting Theora structures needed in header parsing */
        th_comment_init(&theoraComment);
        th_info_init(&theoraInfo);
#endif

        process_audio = 1;
        process_video = 1;
        
        needData = YES;
    }
    return self;
}


- (void) processBegin
{
    if (ogg_page_bos(&oggPage)) {
        int got_packet;
        
        // Initialize a stream state object...
        ogg_stream_state test;
        ogg_stream_init(&test,ogg_page_serialno(&oggPage));
        ogg_stream_pagein(&test, &oggPage);
        
        // Peek at the next packet, since th_decode_headerin() will otherwise
        // eat the first Theora video packet...
        got_packet = ogg_stream_packetpeek(&test, &oggPacket);
        if (!got_packet) {
            return;
        }
        
        /* identify the codec: try theora */
#ifdef OGVKIT_HAVE_DECODER_THEORA
        if(process_video && !theora_p && (theora_processing_headers = th_decode_headerin(&theoraInfo,&theoraComment,&theoraSetupInfo,&oggPacket))>=0){
            
            /* it is theora -- save this stream state */
            memcpy(&theoraStreamState, &test, sizeof(test));
            theora_p = 1;
            
            if (theora_processing_headers == 0) {
                // Saving first video packet for later!
            } else {
                ogg_stream_packetout(&theoraStreamState, NULL);
            }
            return;
        }
#endif

#ifdef OGVKIT_HAVE_DECODER_VORBIS
        if (process_audio && !vorbis_p && (vorbis_processing_headers = vorbis_synthesis_headerin(&vi,&vc,&oggPacket)) == 0) {
            // it's vorbis!
            // save this as our audio stream...
            memcpy(&vo, &test, sizeof(test));
            vorbis_p = 1;
            
            // ditch the processed packet...
            ogg_stream_packetout(&vo, NULL);
            return;
        }
#endif

		/* whatever it is, we don't care about it */
		ogg_stream_clear(&test);
    } else {
        // Not a bitstream start -- move on to header decoding...
        appState = STATE_HEADERS;
    }
}

- (void) processHeaders
{
    if ((theora_p && theora_processing_headers) || (vorbis_p && vorbis_p < 3)) {
        int ret;
        
#ifdef OGVKIT_HAVE_DECODER_THEORA
        /* look for further theora headers */
        if (theora_p && theora_processing_headers) {
            ret = ogg_stream_packetpeek(&theoraStreamState, &oggPacket);
            if (ret < 0) {
                NSLog(@"Error reading theora headers: %d.", ret);
                exit(1);
            }
            if (ret > 0) {
                theora_processing_headers = th_decode_headerin(&theoraInfo, &theoraComment, &theoraSetupInfo, &oggPacket);
                if (theora_processing_headers == 0) {
                    // We've completed the theora header
                    theora_p = 3;
                } else {
                    ogg_stream_packetout(&theoraStreamState, NULL);
                }
            }
        }
#endif

#ifdef OGVKIT_HAVE_DECODER_VORBIS
        if (vorbis_p && (vorbis_p < 3)) {
            ret = ogg_stream_packetpeek(&vo, &oggPacket);
            if (ret < 0) {
                NSLog(@"Error reading vorbis headers: %d.", ret);
                exit(1);
            }
            if (ret > 0) {
                vorbis_processing_headers = vorbis_synthesis_headerin(&vi, &vc, &oggPacket);
                if (vorbis_processing_headers == 0) {
                    vorbis_p++;
                } else {
                    NSLog(@"Invalid vorbis header?");
                    exit(1);
                }
                ogg_stream_packetout(&vo, NULL);
            }
        }
#endif

    } else {
        /* and now we have it all.  initialize decoders */
#ifdef OGVKIT_HAVE_DECODER_THEORA
        if(theora_p){
            theoraDecoderContext=th_decode_alloc(&theoraInfo,theoraSetupInfo);
            
            self.hasVideo = YES;
            self.frameWidth = theoraInfo.frame_width;
            self.frameHeight = theoraInfo.frame_height;
            self.frameRate = (float)theoraInfo.fps_numerator / theoraInfo.fps_denominator;
            self.pictureWidth = theoraInfo.pic_width;
            self.pictureHeight = theoraInfo.pic_height;
            self.pictureOffsetX = theoraInfo.pic_x;
            self.pictureOffsetY = theoraInfo.pic_y;
            self.hDecimation = !(theoraInfo.pixel_fmt & 1);
            self.vDecimation = !(theoraInfo.pixel_fmt & 2);
        }
#endif

#ifdef OGVKIT_HAVE_DECODER_VORBIS
        if (vorbis_p) {
            vorbis_synthesis_init(&vd,&vi);
            vorbis_block_init(&vd,&vb);
            
            self.hasAudio = YES;
            self.audioChannels = vi.channels;
            self.audioRate = (int)vi.rate;
        }
#endif

        appState = STATE_DECODING;
        self.dataReady = YES;
    }
}

- (void)processDecoding
{
    needData = NO;

#ifdef OGVKIT_HAVE_DECODER_THEORA
    if (theora_p && !videobuf_ready) {
        if (ogg_stream_packetpeek(&theoraStreamState, &theoraPacket) > 0) {
            videobuf_ready = 1;
            self.frameReady = YES;
        } else {
            needData = YES;
        }
    }
#endif

#ifdef OGVKIT_HAVE_DECODER_VORBIS
    if (vorbis_p && !audiobuf_ready) {
        if (ogg_stream_packetpeek(&vo, &vorbisPacket) > 0) {
            audiobuf_ready = 1;
            self.audioReady = YES;
        } else {
            needData = YES;
        }
    }
#endif
}

- (BOOL) decodeFrame
{
#ifdef OGVKIT_HAVE_DECODER_THEORA
    if (ogg_stream_packetout(&theoraStreamState, &theoraPacket) <= 0) {
        printf("Theora packet didn't come out of stream\n");
        return NO;
    }
    videobuf_ready=0;
    int ret = th_decode_packetin(theoraDecoderContext, &theoraPacket, &videobuf_granulepos);
    if (ret == 0){
        double t = th_granule_time(theoraDecoderContext,videobuf_granulepos);
        if (t > 0) {
            videobuf_time = t;
        } else {
            // For some reason sometimes we get a bunch of 0s out of th_granule_time
            videobuf_time += 1.0 / ((double)theoraInfo.fps_numerator / theoraInfo.fps_denominator);
        }
        frames++;
        [self doDecodeFrame];
        return YES;
    } else if (ret == TH_DUPFRAME) {
        // Duplicated frame, advance time
        videobuf_time += 1.0 / ((double)theoraInfo.fps_numerator / theoraInfo.fps_denominator);
        frames++;
        [self doDecodeFrame];
        return YES;
    } else {
        printf("Theora decoder failed mysteriously? %d\n", ret);
        return NO;
    }
#else
	return NO;
#endif
}

#ifdef OGVKIT_HAVE_DECODER_THEORA
-(void)doDecodeFrame
{
    assert(queuedFrame == nil);
    
    th_ycbcr_buffer ycbcr;
    th_decode_ycbcr_out(theoraDecoderContext,ycbcr);
    
    OGVFrameBuffer *buffer = [[OGVFrameBuffer alloc] init];
    
    buffer.frameWidth = self.frameWidth;
    buffer.frameHeight = self.frameHeight;
    buffer.pictureWidth = self.pictureWidth;
    buffer.pictureHeight = self.pictureHeight;
    buffer.pictureOffsetX = self.pictureOffsetX;
    buffer.pictureOffsetY = self.pictureOffsetY;
    buffer.hDecimation = self.hDecimation;
    buffer.vDecimation = self.vDecimation;
    
    buffer.strideY = ycbcr[0].stride;
    buffer.strideCb = ycbcr[1].stride;
    buffer.strideCr = ycbcr[2].stride;
    
    size_t lengthY = buffer.strideY * self.frameHeight;
    size_t lengthCb = buffer.strideCb * (self.frameHeight >> self.vDecimation);
    size_t lengthCr = buffer.strideCr * (self.frameHeight >> self.vDecimation);
    
    buffer.dataY = [NSData dataWithBytesNoCopy:ycbcr[0].data length:lengthY freeWhenDone:NO];
    buffer.dataCb = [NSData dataWithBytesNoCopy:ycbcr[1].data length:lengthCb freeWhenDone:NO];
    buffer.dataCr = [NSData dataWithBytesNoCopy:ycbcr[2].data length:lengthCr freeWhenDone:NO];
    
    buffer.timestamp = videobuf_time;
    
    queuedFrame = buffer;
}
#endif

- (BOOL)decodeAudio
{
#ifdef OGVKIT_HAVE_DECODER_VORBIS
    if (ogg_stream_packetout(&vo, &vorbisPacket) > 0) {
        if(vorbis_synthesis(&vb, &vorbisPacket) == 0) {
            vorbis_synthesis_blockin(&vd,&vb);
            
            float **pcm;
            int sampleCount = vorbis_synthesis_pcmout(&vd, &pcm);
            if (sampleCount > 0) {
                queuedAudio = [[OGVAudioBuffer alloc] initWithPCM:pcm channels:self.audioChannels samples:sampleCount];
                vorbis_synthesis_read(&vd, sampleCount);
                self.audioReady = YES;
            }
        }
    }
    return YES;
#else
	return 0;
#endif
}

- (OGVFrameBuffer *)frameBuffer
{
    if (self.frameReady) {
        OGVFrameBuffer *buffer = queuedFrame;
        queuedFrame = nil;
        self.frameReady = NO;
        videobuf_ready = NO;
        return buffer;
    } else {
        @throw [NSException
                exceptionWithName:@"OGVDecoderFrameNotReadyException"
                reason:@"Tried to read frame when none available"
                userInfo:nil];
    }
}

- (OGVAudioBuffer *)audioBuffer
{
    if (self.audioReady) {
        OGVAudioBuffer *buffer = queuedAudio;
        queuedAudio = nil;
        self.audioReady = NO;
        audiobuf_ready = NO;
        return buffer;
    } else {
        @throw [NSException
                exceptionWithName:@"OGVDecoderAudioNotReadyException"
                reason:@"Tried to read audio buffer when none available"
                userInfo:nil];
    }
}

- (void)receiveInput:(NSData *)data
{
    char *buffer = (char *)data.bytes;
    size_t bufsize = data.length;
    if (bufsize > 0) {
        char *dest = ogg_sync_buffer(&oggSyncState, bufsize);
        memcpy(dest, buffer, bufsize);
        ogg_sync_wrote(&oggSyncState, bufsize);
    }
}

- (BOOL)readFromInputStream
{
    if (self.inputStream.state == OGVStreamFileStateDone) {
        // No more data.
        return NO;
    } else {
        NSData *buffer = [self.inputStream readBytes:kOGVDecoderReadBufferSize blocking:YES];
        if (buffer) {
            [self receiveInput:buffer];
            
            // Inform the troops we'll need to do more processing
            // on this shiny new data.
            return YES;
        }
    }
    
    // Need more data and nobody gave it to us!
    return NO;
}

- (BOOL)process
{
    if (needData) {
        if (ogg_sync_pageout(&oggSyncState, &oggPage) > 0) {
#ifdef OGVKIT_HAVE_DECODER_THEORA
            if (theora_p) {
                ogg_stream_pagein(&theoraStreamState, &oggPage);
            }
#endif
#ifdef OGVKIT_HAVE_DECODER_VORBIS
            if (vorbis_p) {
                ogg_stream_pagein(&vo, &oggPage);
            }
#endif
        } else {
            // Out of data!
            return [self readFromInputStream];
        }
    }
    if (appState == STATE_BEGIN) {
        [self processBegin];
    } else if (appState == STATE_HEADERS) {
        [self processHeaders];
    } else if (appState == STATE_DECODING) {
        [self processDecoding];
    }
    return 1;
}


- (void)dealloc
{
#ifdef OGVKIT_HAVE_DECODER_THEORA
    if(theora_p){
        ogg_stream_clear(&theoraStreamState);
        th_decode_free(theoraDecoderContext);
    }
    th_comment_clear(&theoraComment);
    th_info_clear(&theoraInfo);
#endif

#ifdef OGVKIT_HAVE_DECODER_VORBIS
    if (vorbis_p) {
        ogg_stream_clear(&vo);
        vorbis_dsp_clear(&vd);
        vorbis_block_clear(&vb);
    }
    vorbis_comment_clear(&vc);
    vorbis_info_clear(&vi);
#endif

    ogg_sync_clear(&oggSyncState);
}

@end
