//
//  OGVDecoderOgg.m
//  OGVKit
//
//  Created by Brion on 11/2/13.
//  Copyright (c) 2013-2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

#define OV_EXCLUDE_STATIC_CALLBACKS
#include <ogg/ogg.h>

#include <oggz/oggz.h>

#ifdef OGVKIT_HAVE_VORBIS_DECODER
#include <vorbis/vorbisfile.h>
#endif

#ifdef OGVKIT_HAVE_THEORA_DECODER
#include <theora/theoradec.h>
#endif

#import "OGVDecoderOgg.h"
#import "OGVDecoderOggPacket.h"
#import "OGVDecoderOggPacketQueue.h"


@interface OGVDecoderOgg (Private)
- (int)readPacketCallback:(OGVDecoderOggPacket *)packet serialno:(long)serialno;
@end

static const NSUInteger kOGVDecoderReadBufferSize = 65536;

static size_t readCallback(void *user_handle, void *buf, size_t n)
{
    OGVDecoderOgg *decoder = (__bridge OGVDecoderOgg *)user_handle;
    OGVInputStream *stream = decoder.inputStream;
    NSData *data = [stream readBytes:n blocking:YES];
    if (data) {
        assert([data length] <= n);
        memcpy(buf, [data bytes], [data length]);
        return [data length];
    } else {
        return 0;
    }
}

static int seekCallback(void *user_handle, long offset, int whence)
{
    // @todo implement on OGVInputStream
    abort();
    return -1;
}

static long tellCallback(void *user_handle)
{
    OGVDecoderOgg *decoder = (__bridge OGVDecoderOgg *)user_handle;
    OGVInputStream *stream = decoder.inputStream;
    return (long)stream.bytePosition;
}

static int readPacketCallback(OGGZ *oggz, oggz_packet *packet, long serialno, void *user_data)
{
    OGVDecoderOgg *decoder = (__bridge OGVDecoderOgg *)user_data;
    OGVDecoderOggPacket *wrappedPacket = [[OGVDecoderOggPacket alloc] initWithOggzPacket:packet];
    return [decoder readPacketCallback:wrappedPacket serialno:serialno];
}


@implementation OGVDecoderOgg {
    OGGZ *oggz;

    long videoStream;
    OggzStreamContent videoCodec;
    BOOL videoHeadersComplete;
    OGVDecoderOggPacketQueue *videoPackets;

    long audioStream;
    OggzStreamContent audioCodec;
    BOOL audioHeadersComplete;
    OGVDecoderOggPacketQueue *audioPackets;
    
#ifdef OGVKIT_HAVE_THEORA_DECODER
    /* Video decode state */
    //ogg_stream_state  theoraStreamState;
    th_info           theoraInfo;
    th_comment        theoraComment;
    th_setup_info    *theoraSetupInfo;
    th_dec_ctx       *theoraDecoderContext;
    
    int              theora_p;
    int              theora_processing_headers;
#endif
    
    /* single frame video buffering */
    ogg_int64_t  videobuf_granulepos;
    double       videobuf_time;
    OGVVideoBuffer *queuedFrame;
    
    ogg_int64_t  audiobuf_granulepos; /* time position of last sample */
    
    /* Audio decode state */
    int              vorbis_p;
    int              vorbis_processing_headers;
#ifdef OGVKIT_HAVE_VORBIS_DECODER
    //ogg_stream_state vo;
    vorbis_info      vi;
    vorbis_dsp_state vd;
    vorbis_block     vb;
    vorbis_comment   vc;
#endif
    OGVAudioBuffer *queuedAudio;
    BOOL needData;
    
    enum AppState {
        STATE_BEGIN,
        STATE_HEADERS,
        STATE_DECODING
    } appState;
}


- (id)init
{
    self = [super init];
    if (self) {
        self.dataReady = NO;
        
        appState = STATE_BEGIN;
        
        /* start up Ogg stream synchronization layer */
        oggz = oggz_new(OGGZ_READ);
        oggz_io_set_read(oggz, readCallback, (__bridge void *)self);
        oggz_io_set_seek(oggz, seekCallback, (__bridge void *)self);
        oggz_io_set_tell(oggz, tellCallback, (__bridge void *)self);
        oggz_set_read_callback(oggz, -1, readPacketCallback, (__bridge void *)self);

        videoPackets = [[OGVDecoderOggPacketQueue alloc] init];
        audioPackets = [[OGVDecoderOggPacketQueue alloc] init];

#ifdef OGVKIT_HAVE_VORBIS_DECODER
        /* init supporting Vorbis structures needed in header parsing */
        vorbis_info_init(&vi);
        vorbis_comment_init(&vc);
#endif

#ifdef OGVKIT_HAVE_THEORA_DECODER
        /* init supporting Theora structures needed in header parsing */
        th_comment_init(&theoraComment);
        th_info_init(&theoraInfo);
#endif
        
        needData = YES;
    }
    return self;
}

- (int)readPacketCallback:(OGVDecoderOggPacket *)packet serialno:(long)serialno
{
    switch (appState) {
        case STATE_BEGIN:
            return [self processBegin:packet serialno:serialno];
        case STATE_HEADERS:
            return [self processHeaders:packet serialno:serialno];
        case STATE_DECODING:
            return [self processDecoding:packet serialno:serialno];
        default:
            abort();
    }
}

- (int)processBegin:(OGVDecoderOggPacket *)packet serialno:(long)serialno
{
    BOOL bos = packet.oggPacket->b_o_s;
    if (!bos) {
        // Not a bitstream start -- move on to header decoding...
        appState = STATE_HEADERS;
        return [self processHeaders:packet serialno:serialno];
    }

    OggzStreamContent content = oggz_stream_get_content(oggz, serialno);

#ifdef OGVKIT_HAVE_THEORA_DECODER
    if (!videoStream && content == OGGZ_CONTENT_THEORA) {
        videoCodec = content;
        videoStream = serialno;
        int ret = th_decode_headerin(&theoraInfo, &theoraComment, &theoraSetupInfo, packet.oggPacket);
        if (ret == 0) {
            // At end of Theora headers surprisingly early...
            videoHeadersComplete = YES;
            [videoPackets queue:packet];
        } else if (ret > 0) {
            // Still processing headerssssss!
            return OGGZ_CONTINUE;
        } else {
            NSLog(@"Error reading theora headers: %d.", ret);
            return OGGZ_STOP_ERR;
        }
    }
#endif /* OGVKIT_HAVE_THEORA_DECODER */

#ifdef OGVKIT_HAVE_VORBIS_DECODER
    if (!audioStream && content == OGGZ_CONTENT_VORBIS) {
        audioCodec = content;
        audioStream = serialno;

        vorbis_processing_headers = 1;
        int ret = vorbis_synthesis_headerin(&vi, &vc, packet.oggPacket);
        if (ret == 0) {
            // First of 3 header packets down.
            return OGGZ_CONTINUE;
        } else {
            NSLog(@"Error reading Vorbis headers (packet %d): %d", vorbis_processing_headers, ret);
            return OGGZ_STOP_ERR;
        }
        return OGGZ_CONTINUE;
    }
#endif /* OGVKIT_HAVE_VORBIS_DECODER */

    return OGGZ_CONTINUE;
}

- (int) processHeaders:(OGVDecoderOggPacket *)packet serialno:(long)serialno
{
    if (videoStream == serialno) {
        if (videoHeadersComplete) {
            [videoPackets queue:packet];
            // fall through to later logic...
        } else {

#ifdef OGVKIT_HAVE_THEORA_DECODER
            if (videoCodec == OGGZ_CONTENT_THEORA) {
                int ret = th_decode_headerin(&theoraInfo, &theoraComment, &theoraSetupInfo, packet.oggPacket);
                if (ret == 0) {
                    // At end of Theora headers.
                    videoHeadersComplete = YES;

                    theoraDecoderContext = th_decode_alloc(&theoraInfo,theoraSetupInfo);

                    self.hasVideo = YES;
                    self.videoFormat = [[OGVVideoFormat alloc] init];
                    self.videoFormat.frameWidth = theoraInfo.frame_width;
                    self.videoFormat.frameHeight = theoraInfo.frame_height;
                    self.videoFormat.pictureWidth = theoraInfo.pic_width;
                    self.videoFormat.pictureHeight = theoraInfo.pic_height;
                    self.videoFormat.pictureOffsetX = theoraInfo.pic_x;
                    self.videoFormat.pictureOffsetY = theoraInfo.pic_y;
                    self.videoFormat.pixelFormat = [self theoraPixelFormat:theoraInfo.pixel_fmt];

                    return OGGZ_CONTINUE;
                } else if (ret > 0) {
                    // Still processing headerssssss!
                    return OGGZ_CONTINUE;
                } else {
                    NSLog(@"Error reading theora headers: %d.", ret);
                    return OGGZ_STOP_ERR;
                }
            }
#endif /* OGVKIT_HAVE_THEORA_DECODER */

        }
    }

    if (audioStream == serialno) {
        if (audioHeadersComplete) {
            [audioPackets queue:packet];
            // fall through to later logic...
        } else {
        
#ifdef OGVKIT_HAVE_VORBIS_DECODER
            if (audioCodec == OGGZ_CONTENT_VORBIS) {
                vorbis_processing_headers++;
                int ret = vorbis_synthesis_headerin(&vi, &vc, packet.oggPacket);
                if (ret == 0) {
                    // Another successful header down.
                    if (vorbis_processing_headers == 3) {
                        // Oh that was the last one!
                        audioHeadersComplete = YES;
                        vorbis_synthesis_init(&vd,&vi);
                        vorbis_block_init(&vd,&vb);
                        
                        self.hasAudio = YES;
                        self.audioFormat = [[OGVAudioFormat alloc] initWithChannels:vi.channels
                                                                         sampleRate:vi.rate];
                    } else {
                        return OGGZ_CONTINUE;
                    }
                } else {
                    NSLog(@"Error reading Vorbis headers (packet %d): %d", vorbis_processing_headers, ret);
                    return OGGZ_STOP_ERR;
                }
                return OGGZ_CONTINUE;
            }
#endif /* OGVKIT_HAVE_VORBIS_DECODER */

        }
    }

    if ((audioStream && !audioHeadersComplete) || (videoStream && !videoHeadersComplete)) {
        return OGGZ_CONTINUE;
    } else {
        appState = STATE_DECODING;
        self.dataReady = YES;
        return OGGZ_STOP_OK;
    }
}

#ifdef OGVKIT_HAVE_THEORA_DECODER
- (OGVPixelFormat)theoraPixelFormat:(th_pixel_fmt)pixel_fmt
{
    switch (pixel_fmt) {
        case TH_PF_420:
            return OGVPixelFormatYCbCr420;
        case TH_PF_422:
            return OGVPixelFormatYCbCr422;
        case TH_PF_444:
            return OGVPixelFormatYCbCr444;
        default:
            NSLog(@"Invalid pixel format. whoops");
            // @todo handle error state gracefully
            abort();
            return 0;
    }
}
#endif

- (int)processDecoding:(OGVDecoderOggPacket *)packet serialno:(long)serialno
{
    needData = NO;

    if (serialno == videoStream) {
        NSLog(@"queueing video packet");
        [videoPackets queue:packet];
    }
    if (serialno == audioStream) {
        NSLog(@"queueing audio packet");
        [audioPackets queue:packet];
    }

    if (self.hasVideo) {
        if ([videoPackets peek]) {
            self.frameReady = YES;
        } else {
            needData = YES;
        }
    }

    if (self.hasAudio) {
        if ([audioPackets peek]) {
            self.audioReady = YES;
        } else {
            needData = NO;
        }
    }

    if (needData) {
        NSLog(@"processDecode: CONTINUE");
        return OGGZ_CONTINUE;
    } else {
        NSLog(@"processDecode: STOP_OK");
        return OGGZ_STOP_OK;
    }
}

- (BOOL) decodeFrame
{
#ifdef OGVKIT_HAVE_THEORA_DECODER
    if (videoCodec == OGGZ_CONTENT_THEORA) {
        OGVDecoderOggPacket *packet = [videoPackets dequeue];
        int ret = th_decode_packetin(theoraDecoderContext, packet.oggPacket, &videobuf_granulepos);
        if (ret == 0){
            double t = th_granule_time(theoraDecoderContext,videobuf_granulepos);
            if (t > 0) {
                videobuf_time = t;
            } else {
                // For some reason sometimes we get a bunch of 0s out of th_granule_time
                videobuf_time += 1.0 / ((double)theoraInfo.fps_numerator / theoraInfo.fps_denominator);
            }
            [self doDecodeTheora];
            return YES;
        } else if (ret == TH_DUPFRAME) {
            // Duplicated frame, advance time
            videobuf_time += 1.0 / ((double)theoraInfo.fps_numerator / theoraInfo.fps_denominator);
            [self doDecodeTheora];
            return YES;
        } else {
            NSLog(@"Theora decoder failed mysteriously? %d", ret);
            return NO;
        }
    }
#endif /* OGVKIT_HAVE_THEORA_DECODER */

    return NO;
}

#ifdef OGVKIT_HAVE_THEORA_DECODER
-(void)doDecodeTheora
{
    assert(queuedFrame == nil);

    th_ycbcr_buffer ycbcr;
    th_decode_ycbcr_out(theoraDecoderContext, ycbcr);

    OGVVideoPlane *Y = [[OGVVideoPlane alloc] initWithBytes:ycbcr[0].data
                                                     stride:ycbcr[0].stride
                                                      lines:self.videoFormat.lumaHeight];

    OGVVideoPlane *Cb = [[OGVVideoPlane alloc] initWithBytes:ycbcr[1].data
                                                      stride:ycbcr[1].stride
                                                       lines:self.videoFormat.chromaHeight];

    OGVVideoPlane *Cr = [[OGVVideoPlane alloc] initWithBytes:ycbcr[2].data
                                                      stride:ycbcr[2].stride
                                                       lines:self.videoFormat.chromaHeight];

    OGVVideoBuffer *buffer = [[OGVVideoBuffer alloc] initWithFormat:self.videoFormat
                                                                  Y:Y
                                                                 Cb:Cb
                                                                 Cr:Cr
                                                          timestamp:videobuf_time];
    queuedFrame = buffer;
}
#endif

- (BOOL)decodeAudio
{
#ifdef OGVKIT_HAVE_VORBIS_DECODER
    if (audioCodec == OGGZ_CONTENT_VORBIS) {
        OGVDecoderOggPacket *packet = [audioPackets dequeue];

        if(vorbis_synthesis(&vb, packet.oggPacket) == 0) {
            vorbis_synthesis_blockin(&vd, &vb);
            
            float **pcm;
            int sampleCount = vorbis_synthesis_pcmout(&vd, &pcm);
            if (sampleCount > 0) {
                queuedAudio = [[OGVAudioBuffer alloc] initWithPCM:pcm samples:sampleCount format:self.audioFormat];
                vorbis_synthesis_read(&vd, sampleCount);
                self.audioReady = YES;
            }
        }
        return YES;
    }
#endif /* OGVKIT_HAVE_VORBIS_DECODER */

    return NO;
}

- (OGVVideoBuffer *)frameBuffer
{
    if (self.frameReady) {
        OGVVideoBuffer *buffer = queuedFrame;
        queuedFrame = nil;
        self.frameReady = ([videoPackets peek] != nil);
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
        self.audioReady = ([audioPackets peek] != nil);
        return buffer;
    } else {
        @throw [NSException
                exceptionWithName:@"OGVDecoderAudioNotReadyException"
                reason:@"Tried to read audio buffer when none available"
                userInfo:nil];
    }
}

- (BOOL)process
{
    if (needData) {
        NSLog(@"READING:");
        long ret = oggz_read(oggz, kOGVDecoderReadBufferSize);
        if (ret > 0) {
            // just chillin'
            NSLog(@"READ A BUNCH OF DATA from oggz_read? frameReady:%d audioReady:%d", (int)self.frameReady, (int)self.audioReady);
            return 1;
        } else if (ret == 0) {
            // end of file
            NSLog(@"END OF FILE from oggz_read?");
            return 0;
        } else if (ret == OGGZ_ERR_STOP_OK) {
            // we processed enough packets for now,
            // but come back for more later please!
            NSLog(@"ASKED TO STOP from oggz_read? %d %d", (int)self.frameReady, (int)self.audioReady);
            return 1;
        } else {
            NSLog(@"Error from oggz_read? %ld", ret);
            abort();
        }
    } else if (self.inputStream.state != OGVInputStreamStateReading) {
        NSLog(@"Input stream done or errored %d", (int)self.inputStream.state);
        return 0;
    }
    
    // nothing to do right now (??)
    return 1;
}


- (void)dealloc
{
#ifdef OGVKIT_HAVE_THEORA_DECODER
    if (videoCodec == OGGZ_CONTENT_THEORA) {
        th_decode_free(theoraDecoderContext);
    }
    th_comment_clear(&theoraComment);
    th_info_clear(&theoraInfo);
#endif

#ifdef OGVKIT_HAVE_VORBIS_DECODER
    if (audioCodec == OGGZ_CONTENT_VORBIS) {
        vorbis_dsp_clear(&vd);
        vorbis_block_clear(&vb);
    }
    vorbis_comment_clear(&vc);
    vorbis_info_clear(&vi);
#endif

    oggz_close(oggz);
}

+ (BOOL)canPlayType:(OGVMediaType *)mediaType
{
    if ([mediaType.minor isEqualToString:@"ogg"] &&
        ([mediaType.major isEqualToString:@"application"] ||
         [mediaType.major isEqualToString:@"audio"] ||
         [mediaType.major isEqualToString:@"video"])
        ) {

        if (mediaType.codecs) {
            int knownCodecs = 0;
            int unknownCodecs = 0;
            for (NSString *codec in mediaType.codecs) {
#ifdef OGVKIT_HAVE_THEORA_DECODER
                if ([codec isEqualToString:@"theora"]) {
                    knownCodecs++;
                    continue;
                }
#endif
#ifdef OGVKIT_HAVE_VORBIS_DECODER
                if ([codec isEqualToString:@"vorbis"]) {
                    knownCodecs++;
                    continue;
                }
#endif
                unknownCodecs++;
            }
            if (knownCodecs == 0) {
                return OGVCanPlayNo;
            }
            if (unknownCodecs > 0) {
                return OGVCanPlayNo;
            }
            // All listed codecs are ones we know. Neat!
            return OGVCanPlayProbably;
        } else {
            return OGVCanPlayMaybe;
        }
    } else {
        return OGVCanPlayNo;
    }
}

@end
