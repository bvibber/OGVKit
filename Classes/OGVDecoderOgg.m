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
    OGVDecoderOgg *decoder = (__bridge OGVDecoderOgg *)user_handle;
    OGVInputStream *stream = decoder.inputStream;
    int64_t position;
    switch (whence) {
        case SEEK_SET:
            position = offset;
            break;
        case SEEK_CUR:
            position = stream.bytePosition + offset;
            break;
        case SEEK_END:
            position = stream.length + offset;
            break;
        default:
            return -1;
    }
    [stream seek:position blocking:YES];
    return (int)position;
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

    float duration;

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
    
    enum AppState {
        STATE_BEGIN,
        STATE_HEADERS,
        STATE_DURATION,
        STATE_DECODING
    } appState;
}


- (id)init
{
    self = [super init];
    if (self) {
        self.dataReady = NO;

        appState = STATE_BEGIN;
        duration = INFINITY;

        /* start up Ogg stream synchronization layer */
        oggz = oggz_new(OGGZ_READ | OGGZ_AUTO);
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
        case STATE_DURATION:
            // In duration check state we just want to run through the stream
            // until we find the last packet, and check its time.
            return OGGZ_CONTINUE;
        case STATE_DECODING:
            return [self processDecoding:packet serialno:serialno];
        default:
            NSLog(@"Invalid state in Ogg readPacketCallback");
            return OGGZ_STOP_ERR;
    }
}

- (int)processBegin:(OGVDecoderOggPacket *)packet serialno:(long)serialno
{
    BOOL bos = (packet.oggPacket->b_o_s != 0);
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
            NSLog(@"Theora headers ended after first packet, which is impossible");
            return OGGZ_STOP_ERR;
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
    assert(audioStream || videoStream);

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

                    self.videoFormat = [[OGVVideoFormat alloc] init];
                    self.videoFormat.frameWidth = theoraInfo.frame_width;
                    self.videoFormat.frameHeight = theoraInfo.frame_height;
                    self.videoFormat.pictureWidth = theoraInfo.pic_width;
                    self.videoFormat.pictureHeight = theoraInfo.pic_height;
                    self.videoFormat.pictureOffsetX = theoraInfo.pic_x;
                    self.videoFormat.pictureOffsetY = theoraInfo.pic_y;
                    self.videoFormat.pixelFormat = [self theoraPixelFormat:theoraInfo.pixel_fmt];

                    // Surprise! This is actually the first video packet.
                    // Save it for later.
                    [videoPackets queue:packet];
                } else if (ret > 0) {
                    // Still processing headerssssss!
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
                        
                        self.audioFormat = [[OGVAudioFormat alloc] initWithChannels:vi.channels
                                                                         sampleRate:vi.rate];
                    }
                } else {
                    NSLog(@"Error reading Vorbis headers (packet %d): %d", vorbis_processing_headers, ret);
                    return OGGZ_STOP_ERR;
                }
            }
#endif /* OGVKIT_HAVE_VORBIS_DECODER */

        }
    }

    BOOL isComplete = YES;
    if (audioStream) {
        isComplete = isComplete && audioHeadersComplete;
    }
    if (videoStream) {
        isComplete = isComplete && videoHeadersComplete;
    }
    if (isComplete) {
        appState = STATE_DURATION;
        return OGGZ_STOP_OK;
    } else {
        return OGGZ_CONTINUE;
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

-(BOOL)extractDuration
{
    // @todo use X-Content-Duration from stream if available
    // @todo use ogg skeleton track info if available
    
    // Do it the hard way: seek to the end and find the time of the last packet.
    // Beware this will be slow over the network.
    if (self.inputStream.seekable) {
        long endChunkSize = 256 * 1024;
        //oggz_off_t currentPosition = oggz_tell(oggz);

        oggz_off_t ret = oggz_seek(oggz, -endChunkSize, SEEK_END);
        if (ret < 0) {
            NSLog(@"Unable to seek to end of Ogg file for duration check.");
            return NO;
        }
        
        while (true) {
            long readRet = oggz_read(oggz, kOGVDecoderReadBufferSize);
            if (readRet == OGGZ_ERR_HOLE_IN_DATA) {
                // We seeked to mid-stream so this is expected.
                NSLog(@"resyncing ogg stream...");
                continue;
            } else if (readRet == OGGZ_ERR_STOP_OK) {
                // Not sure why this happens. Our callback should
                // not be returning it during seek state!
                continue;
            } else if (readRet == 0) {
                // Got to the end of the file.
                break;
            } else if (readRet < 0) {
                NSLog(@"Error %d reading for Ogg file duration.", (int)readRet);
                return NO;
            } else {
                // processed some number of bytes...
            }
        }

        ogg_int64_t finalTime = oggz_tell_units(oggz);
        if (finalTime < 0) {
            NSLog(@"Unable to read time from end of Ogg file for duration check: %d", (int)finalTime);
            return NO;
        }
        duration = (float)finalTime / 1000.0f;
        NSLog(@"duration: %f", duration);

        ret = oggz_seek(oggz, 0, SEEK_SET);
        if (ret < 0) {
            NSLog(@"Unable to seek back to current Ogg position in duration check: %d", (int)ret);
            return NO;
        }

        [self flush];
    }

    return YES;
}

- (int)processDecoding:(OGVDecoderOggPacket *)packet serialno:(long)serialno
{
    if (serialno == videoStream) {
        [videoPackets queue:packet];
    }

    if (serialno == audioStream) {
        [audioPackets queue:packet];
    }

    if (self.frameReady || self.audioReady) {
        return OGGZ_STOP_OK;
    } else {
        return OGGZ_CONTINUE;
    }
}

- (BOOL) decodeFrame
{
    OGVDecoderOggPacket *packet = [videoPackets dequeue];

#ifdef OGVKIT_HAVE_THEORA_DECODER
    if (videoCodec == OGGZ_CONTENT_THEORA) {
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
    OGVDecoderOggPacket *packet = [audioPackets dequeue];

#ifdef OGVKIT_HAVE_VORBIS_DECODER
    if (audioCodec == OGGZ_CONTENT_VORBIS) {
        int ret = vorbis_synthesis(&vb, packet.oggPacket);
        if (ret == 0) {
            vorbis_synthesis_blockin(&vd, &vb);
            
            float **pcm;
            int sampleCount = vorbis_synthesis_pcmout(&vd, &pcm);
            if (sampleCount > 0) {
                queuedAudio = [[OGVAudioBuffer alloc] initWithPCM:pcm samples:sampleCount format:self.audioFormat];
                vorbis_synthesis_read(&vd, sampleCount);
                return YES;
            } else {
                NSLog(@"Vorbis decoder gave empty packet; ignore it!");
                return NO;
            }
        } else {
            NSLog(@"Vorbis decoder failed mysteriously? %d", ret);
            return NO;
        }
    }
#endif /* OGVKIT_HAVE_VORBIS_DECODER */

    return NO;
}

- (OGVVideoBuffer *)frameBuffer
{
    if (queuedFrame) {
        OGVVideoBuffer *buffer = queuedFrame;
        queuedFrame = nil;
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
    if (queuedAudio) {
        OGVAudioBuffer *buffer = queuedAudio;
        queuedAudio = nil;
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
    BOOL needData;
    switch (appState) {
        case STATE_DURATION:
            if ([self extractDuration]) {
                self.hasVideo = videoHeadersComplete;
                self.hasAudio = audioHeadersComplete;
                self.dataReady = YES;
                
                appState = STATE_DECODING;
                return YES;
            } else {
                // something exploded
                NSLog(@"error during Ogg duration extraction");
                return NO;
            }
            break;

        case STATE_BEGIN:
        case STATE_HEADERS:
            needData = YES;
            break;
            
        case STATE_DECODING:
            needData = (self.hasAudio && audioPackets.empty) ||
                       (self.hasVideo && videoPackets.empty);
            break;

        default:
            NSLog(@"Invalid internal state %d in OGVDecoderOgg", (int)appState);
            return NO;
    }

    if (needData) {
        //NSLog(@"READING:");
        long ret = oggz_read(oggz, kOGVDecoderReadBufferSize);
        if (ret > 0) {
            // just chillin'
            //NSLog(@"READ A BUNCH OF DATA from oggz_read? frameReady:%d audioReady:%d", (int)self.frameReady, (int)self.audioReady);
            return 1;
        } else if (ret == 0) {
            // end of file
            NSLog(@"END OF FILE from oggz_read?");
            return 0;
        } else if (ret == OGGZ_ERR_STOP_OK) {
            // we processed enough packets for now,
            // but come back for more later please!
            //NSLog(@"ASKED TO STOP from oggz_read? %d %d", (int)self.frameReady, (int)self.audioReady);
            return 1;
        } else {
            NSLog(@"Error from oggz_read? %ld", ret);
            abort();
        }
    } else if (self.inputStream.state == OGVInputStreamStateReading) {
        // nothing to do right now (??)
        return 1;
    } else if (self.inputStream.state == OGVInputStreamStateSeeking) {
        // this shouldn't actually happen!
        NSLog(@"Called decoder process during seeking, beware!");
        return 1;
    } else {
        NSLog(@"Input stream done or errored, state %d", (int)self.inputStream.state);
        return 0;
    }
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

-(void)flush
{
    if (videoStream) {
        queuedFrame = nil;
        [videoPackets flush];
    }

    if (audioStream) {
        queuedAudio = nil;
        [audioPackets flush];
    }
}

#pragma mark - property getters

- (BOOL)frameReady
{
    return appState == STATE_DECODING && !videoPackets.empty;
}

- (BOOL)audioReady
{
    return appState == STATE_DECODING && !audioPackets.empty;
}

- (float)duration
{
    return duration;
}

#pragma mark - class methods

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
