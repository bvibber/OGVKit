//
//  OGVDecoderWebM.m
//  OGVKit
//
//  Created by Brion on 6/17/15.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"
#import "OGVQueue.h"
#import "OGVDecoderWebM.h"
#import "OGVDecoderWebMPacket.h"

#include <nestegg/nestegg.h>

#ifdef OGVKIT_HAVE_VP8_DECODER
#define VPX_CODEC_DISABLE_COMPAT 1
#include <VPX/vpx/vpx_decoder.h>
#include <VPX/vpx/vp8dx.h>
#endif

#ifdef OGVKIT_HAVE_VORBIS_DECODER
#include <ogg/ogg.h>
#include <vorbis/codec.h>
#endif

// Does a brute-force seek when asked to seek WebM files without cues
#define OGVKIT_WEBM_SEEK_BRUTE_FORCE 1

static void logCallback(nestegg *context, unsigned int severity, char const * format, ...)
{
    if (severity >= NESTEGG_LOG_INFO) {
        va_list args;
        va_start(args, format);
        vprintf(format, args);
        va_end(args);
    }
}

static int readCallback(void * buffer, size_t length, void *userdata)
{
    OGVDecoderWebM *decoder = (__bridge OGVDecoderWebM *)userdata;
    OGVInputStream *stream = decoder.inputStream;
    NSData *data = [stream readBytes:length blocking:YES];

    if (stream.state == OGVInputStreamStateFailed) {
        return 0;
    } else if ([data length] < length) {
        // out of data unexpectedly
        return 0;
    } else {
        assert([data length] == length);
        memcpy(buffer, [data bytes], [data length]);
        return 1;
    }
}

static int seekCallback(int64_t offset, int whence, void * userdata)
{
    OGVDecoderWebM *decoder = (__bridge OGVDecoderWebM *)userdata;
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
    if (stream.state == OGVInputStreamStateFailed) {
        return -1;
    } else {
        return 0;
    }
}

static int64_t tellCallback(void * userdata)
{
    OGVDecoderWebM *decoder = (__bridge OGVDecoderWebM *)userdata;
    OGVInputStream *stream = decoder.inputStream;
    return (int64_t)stream.bytePosition;
}

@implementation OGVDecoderWebM
{
    nestegg        *demuxContext;
    nestegg_io      ioCallbacks;
    char           *bufferQueue;
    size_t          bufferSize;
    uint64_t        bufferBytesRead;
    
    unsigned int    videoTrack;
    int             videoCodec;
    OGVQueue       *videoPackets;
    
    unsigned int    audioTrack;
    int             audioCodec;
    unsigned int    audioPacketCount;
    OGVQueue       *audioPackets;
    

#ifdef OGVKIT_HAVE_VP8_DECODER
    vpx_codec_ctx_t    vpxContext;
    vpx_codec_iface_t *vpxDecoder;
#endif
    
    /* single frame video buffering */
    int64_t           videobufGranulepos;  // @todo reset with TH_CTL_whatver on seek
    double            videobufTime;         // time seen on actual decoded frame
    int64_t           keyframeGranulepos;  //
    double            keyframeTime;        // last-keyframe time seen on actual decoded frame
    
    int64_t           audiobufGranulepos; /* time position of last sample */
    double            audiobufTime;

#ifdef OGVKIT_HAVE_VORBIS_DECODER
    /* Audio decode state */
    int               vorbisHeaders;
    int               vorbisProcessingHeaders;
    vorbis_info       vorbisInfo;
    vorbis_dsp_state  vorbisDspState;
    vorbis_block      vorbisBlock;
    vorbis_comment    vorbisComment;
#endif

    OGVAudioBuffer *queuedAudio;
    OGVVideoBuffer *queuedFrame;

    enum AppState {
        STATE_BEGIN,
        STATE_DECODING
    } appState;
}


-(instancetype)init
{
    self = [super init];
    if (self) {
        //
        appState = STATE_BEGIN;
        videoCodec = -1;
        videoPackets = [[OGVQueue alloc] init];
        audioCodec = -1;
        audioPackets = [[OGVQueue alloc] init];

        ioCallbacks.read = readCallback;
        ioCallbacks.seek = seekCallback;
        ioCallbacks.tell = tellCallback;
        ioCallbacks.userdata = (__bridge void *)self;
        
#ifdef OGVKIT_HAVE_VORBIS_DECODER
        /* init supporting Vorbis structures needed in header parsing */
        vorbis_info_init(&vorbisInfo);
        vorbis_comment_init(&vorbisComment);
#endif
    }
    return self;
}

-(BOOL)processBegin
{
    if (nestegg_init(&demuxContext, ioCallbacks, logCallback, -1) < 0) {
        NSLog(@"nestegg_init failed");
        return NO;
    }
    
    // Look through the tracks finding our video and audio
    BOOL hasVideo = NO;
    BOOL hasAudio = NO;
    unsigned int tracks;
    if (nestegg_track_count(demuxContext, &tracks) < 0) {
        tracks = 0;
    }
    for (unsigned int track = 0; track < tracks; track++) {
        int trackType = nestegg_track_type(demuxContext, track);
        int codec = nestegg_track_codec_id(demuxContext, track);
        
        if (trackType == NESTEGG_TRACK_VIDEO && !hasVideo) {
#ifdef OGVKIT_HAVE_VP8_DECODER
            if (codec == NESTEGG_CODEC_VP8 || codec == NESTEGG_CODEC_VP9) {
                hasVideo = YES;
                videoTrack = track;
                videoCodec = codec;
            }
#endif
        }
        
        if (trackType == NESTEGG_TRACK_AUDIO && !hasAudio) {
#ifdef OGVKIT_HAVE_VORBIS_DECODER
            if (codec == NESTEGG_CODEC_VORBIS /* || codec == NESTEGG_CODEC_OPUS */) {
                hasAudio = YES;
                audioTrack = track;
                audioCodec = codec;
            }
#endif
        }
    }
    
    if (hasVideo) {
        nestegg_video_params videoParams;
        if (nestegg_track_video_params(demuxContext, videoTrack, &videoParams) < 0) {
            // failed! something is wrong...
            return NO;
        } else {
#ifdef OGVKIT_HAVE_VP8_DECODER
            if (videoCodec == NESTEGG_CODEC_VP8) {
                vpxDecoder = vpx_codec_vp8_dx();
            } else if (videoCodec == NESTEGG_CODEC_VP9) {
                vpxDecoder = vpx_codec_vp9_dx();
            }
            vpx_codec_dec_init(&vpxContext, vpxDecoder, NULL, 0);

            self.videoFormat = [[OGVVideoFormat alloc] init];
            self.videoFormat.frameWidth = videoParams.width;
            self.videoFormat.frameHeight = videoParams.height;
            self.videoFormat.pictureWidth = videoParams.display_width;
            self.videoFormat.pictureHeight = videoParams.display_height;
            self.videoFormat.pictureOffsetX = videoParams.crop_left;
            self.videoFormat.pictureOffsetY = videoParams.crop_top;
            self.videoFormat.pixelFormat = OGVPixelFormatYCbCr420; // @todo vp9 can do other formats too
#endif
        }
    }
    
    if (hasAudio) {
        nestegg_audio_params audioParams;
        if (nestegg_track_audio_params(demuxContext, audioTrack, &audioParams) < 0) {
            // failed! something is wrong
            return NO;
        } else {
#ifdef OGVKIT_HAVE_VORBIS_DECODER
            if (audioCodec == NESTEGG_CODEC_VORBIS) {
                unsigned int codecDataCount;
                nestegg_track_codec_data_count(demuxContext, audioTrack, &codecDataCount);

                for (unsigned int i = 0; i < codecDataCount; i++) {
                    unsigned char *data;
                    size_t len;
                    int ret = nestegg_track_codec_data(demuxContext, audioTrack, i, &data, &len);
                    if (ret < 0) {
                        NSLog(@"failed to read codec data %d", i);
                        return NO;
                    }
                    ogg_packet audioPacket;
                    audioPacket.packet = data;
                    audioPacket.bytes = len;
                    audioPacket.b_o_s = (i == 0);
                    audioPacket.e_o_s = 0;
                    audioPacket.granulepos = 0;
                    audioPacket.packetno = i;

                    ret = vorbis_synthesis_headerin(&vorbisInfo, &vorbisComment, &audioPacket);
                    if (ret == 0) {
                        vorbisHeaders++;
                    } else {
                        NSLog(@"Invalid vorbis header? %d", ret);
                        return NO;
                    }
                }
            }
#endif
        }
    }
    
#ifdef OGVKIT_HAVE_VORBIS_DECODER
	if (vorbisHeaders) {
		vorbis_synthesis_init(&vorbisDspState, &vorbisInfo);
		vorbis_block_init(&vorbisDspState, &vorbisBlock);
		
        self.audioFormat = [[OGVAudioFormat alloc] initWithChannels:vorbisInfo.channels
                                                         sampleRate:vorbisInfo.rate];
	}
#endif

    appState = STATE_DECODING;
    self.dataReady = YES;
    self.hasAudio = hasAudio;
    self.hasVideo = hasVideo;

    return YES;
}

-(BOOL)processDecoding
{
    BOOL needData = NO;
    
    if (self.hasVideo && !self.frameReady) {
        needData = YES;
    }

    if (self.hasAudio && !self.audioReady) {
        needData = YES;
    }

    if (needData) {
        // Do the nestegg_read_packet dance until it fails to read more data,
        // at which point we ask for more. Hope it doesn't explode.
        nestegg_packet *nepacket = NULL;
        int ret = nestegg_read_packet(demuxContext, &nepacket);
        if (ret == 0) {
            // end of stream?
            return NO;
        } else if (ret > 0) {
            [self _queue:[[OGVDecoderWebMPacket alloc] initWithNesteggPacket:nepacket]];
        }
    }
    
    return YES;
}

-(void)_queue:(OGVDecoderWebMPacket *)packet
{
    unsigned int track;
    nestegg_packet_track(packet.nesteggPacket, &track);

    if (self.hasVideo && track == videoTrack) {
        [videoPackets queue:packet];
    } else if (self.hasAudio && track == audioTrack) {
        [audioPackets queue:packet];
    } else {
        // throw away unknown packets
    }
}

-(BOOL)decodeFrame
{
    OGVDecoderWebMPacket *packet = [videoPackets dequeue];
    
    if (packet) {
        unsigned int chunks = packet.count;

        videobufTime = packet.timestamp;
        if (queuedFrame) {
            [queuedFrame neuter];
            queuedFrame = nil;
        }

#ifdef OGVKIT_HAVE_VP8_DECODER
        // uh, can this happen? curiouser :D
        for (unsigned int chunk = 0; chunk < chunks; ++chunk) {
            NSData *data = [packet dataAtIndex:chunk];

            vpx_codec_decode(&vpxContext, data.bytes, (unsigned int)[data length], NULL, 1);
            // @todo check return value
        }
        // last chunk!
        vpx_codec_decode(&vpxContext, NULL, 0, NULL, 1);
        
        vpx_codec_iter_t iter = NULL;
        vpx_image_t *image = NULL;
        bool foundImage = false;
        while ((image = vpx_codec_get_frame(&vpxContext, &iter))) {
            // is it possible to get more than one at a time? ugh
            // @fixme can we have multiples really? how does this worky
            if (foundImage) {
                // skip for now
                continue;
            }
            foundImage = true;

            // In VP8/VP9 the frame size can vary! Update as necessary.
            // vpx_image is pre-cropped; use only the display size
            OGVVideoFormat *format = [[OGVVideoFormat alloc] init];
            format.frameWidth = image->d_w;
            format.frameHeight = image->d_h;
            format.pictureWidth = image->d_w;
            format.pictureHeight = image->d_h;
            switch (image->fmt) {
                case VPX_IMG_FMT_I420:
                    format.pixelFormat = OGVPixelFormatYCbCr420;
                    break;
                case VPX_IMG_FMT_I422:
                    format.pixelFormat = OGVPixelFormatYCbCr422;
                    break;
                case VPX_IMG_FMT_I444:
                    format.pixelFormat = OGVPixelFormatYCbCr444;
                    break;
                default:
                    [NSException raise:@"OGVDecoderWebMException"
                                format:@"Unexpected VPX pixel format %d", (int)image->fmt];
            }
            switch (image->cs) {
                case VPX_CS_BT_601:
                    format.colorSpace = OGVColorSpaceBT601;
                    break;
                case VPX_CS_BT_709:
                    format.colorSpace = OGVColorSpaceBT709;
                    break;
                case VPX_CS_SMPTE_170:
                    format.colorSpace = OGVColorSpaceSMPTE170;
                    break;
                case VPX_CS_SMPTE_240:
                    format.colorSpace = OGVColorSpaceSMPTE240;
                    break;
                case VPX_CS_BT_2020:
                    format.colorSpace = OGVColorSpaceBT2020;
                    break;
                case VPX_CS_UNKNOWN:
                default:
                    format.colorSpace = OGVColorSpaceDefault;
            }
            if (![format isEqual:self.videoFormat]) {
                self.videoFormat = format;
            }

            OGVVideoPlane *Y = [[OGVVideoPlane alloc] initWithBytes:image->planes[0]
                                                             stride:image->stride[0]
                                                              lines:format.lumaHeight];

            OGVVideoPlane *Cb = [[OGVVideoPlane alloc] initWithBytes:image->planes[1]
                                                              stride:image->stride[1]
                                                               lines:format.chromaHeight];

            OGVVideoPlane *Cr = [[OGVVideoPlane alloc] initWithBytes:image->planes[2]
                                                              stride:image->stride[2]
                                                               lines:format.chromaHeight];

            OGVVideoBuffer *buffer = [[OGVVideoBuffer alloc] initWithFormat:self.videoFormat
                                                                          Y:Y
                                                                         Cb:Cb
                                                                         Cr:Cr
                                                                  timestamp:videobufTime];

            queuedFrame = buffer;

            return YES;
        }
#endif
        
        return NO;
    }

    return NO;
}

-(BOOL)decodeAudio
{
    BOOL foundSome = NO;
    
    OGVDecoderWebMPacket *packet = [audioPackets dequeue];

    if (packet) {

#ifdef OGVKIT_HAVE_VORBIS_DECODER
        if (audioCodec == NESTEGG_CODEC_VORBIS) {
            ogg_packet audioPacket;
            [packet synthesizeOggPacket:&audioPacket];

            int ret = vorbis_synthesis(&vorbisBlock, &audioPacket);
            if (ret == 0) {
                vorbis_synthesis_blockin(&vorbisDspState, &vorbisBlock);
                
                float **pcm;
                int sampleCount = vorbis_synthesis_pcmout(&vorbisDspState, &pcm);
                if (sampleCount > 0) {
                    foundSome = YES;
                    queuedAudio = [[OGVAudioBuffer alloc] initWithPCM:pcm samples:sampleCount format:self.audioFormat timestamp:packet.timestamp];
                    
                    vorbis_synthesis_read(&vorbisDspState, sampleCount);
                    if (audiobufGranulepos != -1) {
                        // keep track of how much time we've decodec
                        audiobufGranulepos += sampleCount;
                        audiobufTime = (double)audiobufGranulepos / self.audioFormat.sampleRate;
                    }
                } else {
                    NSLog(@"Vorbis decoder gave an empty packet!");
                }
            } else {
                NSLog(@"Vorbis decoder failed mysteriously? %d", ret);
            }
        }
#endif
    }

    return foundSome;
}

-(BOOL)process
{
    if (appState == STATE_BEGIN) {
        return [self processBegin];
    } else if (appState == STATE_DECODING) {
        return [self processDecoding];
    } else {
        // uhhh...
        NSLog(@"Invalid appState in -[OGVDecoderWebM process]\n");
        return NO;
    }
}


- (OGVVideoBuffer *)frameBuffer
{
    return queuedFrame;
}

- (OGVAudioBuffer *)audioBuffer
{
    return queuedAudio;
}

-(void)dealloc
{
#ifdef OGVKIT_HAVE_VORBIS_DECODER
    if (vorbisHeaders) {
        //ogg_stream_clear(&vorbisStreamState);
        vorbis_dsp_clear(&vorbisDspState);
        vorbis_block_clear(&vorbisBlock);
        vorbis_comment_clear(&vorbisComment);
        vorbis_info_clear(&vorbisInfo);
    }
#endif
#ifdef OGVKIT_HAVE_VP8_DECODER
    if (vpxDecoder) {
        vpx_codec_destroy(&vpxContext);
        vpxDecoder = NULL;
    }
#endif
    if (demuxContext) {
        nestegg_destroy(demuxContext);
    }
}


-(void)flush
{
    if (self.hasVideo) {
        queuedFrame = nil;
        [videoPackets flush];
    }
    
    if (self.hasAudio) {
        queuedAudio = nil;
        [audioPackets flush];

#ifdef OGVKIT_HAVE_VORBIS_DECODER
        if (audioCodec == NESTEGG_CODEC_VORBIS) {
            vorbis_synthesis_restart(&vorbisDspState);
        }
#endif
    }
}

- (BOOL)seek:(float)seconds
{
    if (self.seekable) {
        int64_t nanoseconds = (int64_t)(seconds * NSEC_PER_SEC);
        int ret = nestegg_track_seek(demuxContext, self.hasVideo ? videoTrack : audioTrack, nanoseconds);
        if (ret < 0) {
            // uhhh.... not good.
#ifdef OGVKIT_WEBM_SEEK_BRUTE_FORCE
            NSLog(@"brute force WebM seek; restarting file");
            [self.inputStream seek:0L blocking:YES];
            ret = nestegg_init(&demuxContext, ioCallbacks, logCallback, -1);
            if (ret < 0) {
                NSLog(@"nestegg_init returned %d", ret);
            }
            while (YES) {
                nestegg_packet *nepacket;
                ret = nestegg_read_packet(demuxContext, &nepacket);
                if (ret == 0) {
                    // end of stream?
                    NSLog(@"End of stream during brute-force WebM seek");
                    return NO;
                } else if (ret > 0) {
                    OGVDecoderWebMPacket *packet = [[OGVDecoderWebMPacket alloc] initWithNesteggPacket:nepacket];
                    if (packet.timestamp < seconds) {
                        // keep going
                        continue;
                    } else {
                        // We found it!
                        NSLog(@"brute force WebM seek found destination!");
                        [self _queue:packet];
                        return YES;
                    }
                } else {
                    // err
                    NSLog(@"nestegg_read_packet returned %d", ret);
                    return NO;
                }
            }
#else
            NSLog(@"OGVDecoderWebM failed to seek to time position within file");
            return NO;
#endif /* OGVKIT_WEBM_SEEK_BRUTE_FORCE */
        } else {
            [self flush];
            return YES;
        }
    } else {
        return NO;
    }
}

#pragma mark - property getters

- (BOOL)frameReady
{
    return appState == STATE_DECODING && !videoPackets.empty;
}

- (float)frameTimestamp
{
    if (self.frameReady) {
        OGVDecoderWebMPacket *packet = [videoPackets peek];
        return packet.timestamp;
    } else {
        return -1;
    }
}

- (BOOL)audioReady
{
    return appState == STATE_DECODING && !audioPackets.empty;
}

- (float)audioTimestamp
{
    if (self.audioReady) {
        OGVDecoderWebMPacket *packet = [audioPackets peek];
        return packet.timestamp;
    } else {
        return -1;
    }
}

-(BOOL)seekable
{
    return self.dataReady &&
        self.inputStream.seekable &&
        demuxContext/* &&
        nestegg_has_cues(demuxContext)*/;
}

-(float)duration
{
    if (demuxContext) {
        uint64_t duration_ns;
        if (nestegg_duration(demuxContext, &duration_ns) == 0) {
            return duration_ns / 1000000000.0;
        }
    }
    return INFINITY;
}

#pragma mark - class methods

+ (BOOL)canPlayType:(OGVMediaType *)mediaType
{
    if ([mediaType.minor isEqualToString:@"webm"] &&
         ([mediaType.major isEqualToString:@"audio"] ||
          [mediaType.major isEqualToString:@"video"])
        ) {

        if (mediaType.codecs) {
            int knownCodecs = 0;
            int unknownCodecs = 0;
            for (NSString *codec in mediaType.codecs) {
#ifdef OGVKIT_HAVE_VP8_DECODER
                if ([codec isEqualToString:@"vp8"]) {
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
