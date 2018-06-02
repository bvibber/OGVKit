//
//  OGVVP8Encoder
//  OGVKit
//
//  Copyright (c) 2016-2018 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"
#import "OGVVP8Encoder.h"

#define VPX_CODEC_DISABLE_COMPAT 1
#include <VPX/vpx/vpx_encoder.h>
#include <VPX/vpx/vp8cx.h>

@implementation OGVVP8Encoder
{
    vpx_codec_ctx_t codec;
    unsigned long deadline;
}

-(instancetype)initWithFormat:(OGVVideoFormat *)format options:(NSDictionary *)options
{
    self = [super initWithFormat:format options:options];
    if (self) {
        vpx_codec_iface_t *encoderInterface = vpx_codec_vp8_cx();

        vpx_codec_enc_cfg_t cfg;
        vpx_codec_enc_config_default(encoderInterface, &cfg, 0);
        cfg.g_threads = (unsigned int)[NSProcessInfo processInfo].activeProcessorCount;
        cfg.g_w = format.frameWidth;
        cfg.g_h = format.frameHeight;
        cfg.g_timebase.num = 1;
        cfg.g_timebase.den = 1000;

        NSNumber *bitrate = options[OGVVideoEncoderOptionsBitrateKey];
        if (bitrate) {
            cfg.rc_target_bitrate = bitrate.intValue / 1000;
        }

        cfg.kf_mode = VPX_KF_AUTO;
        cfg.kf_min_dist = 0;
        NSNumber *interval = options[OGVVideoEncoderOptionsKeyframeIntervalKey];
        if (interval) {
            cfg.kf_max_dist = interval.intValue;
        } else {
            // some reasonable default
            cfg.kf_max_dist = 256;
        }
        cfg.g_usage = 0;
        
        vpx_codec_enc_init(&codec, encoderInterface, &cfg, 0);

        NSNumber *realtime = options[OGVVideoEncoderOptionsRealtimeKey];
        if (realtime && realtime.boolValue) {
            deadline = VPX_DL_REALTIME;
        } else {
            deadline = VPX_DL_GOOD_QUALITY;
            cfg.g_lag_in_frames = 25;
        }

        NSNumber *speed = options[OGVVideoEncoderOptionsSpeedKey];
        if (speed) {
            //vpx_codec_control(&codec, VP8E_SET_CPUUSED, 8); // feels pretty fast, quality is meh
            //vpx_codec_control(&codec, VP8E_SET_CPUUSED, 4); // little better balance
            //vpx_codec_control(&codec, VP8E_SET_CPUUSED, 2); // pretty darn slow
            vpx_codec_control(&codec, VP8E_SET_CPUUSED, speed.intValue);
        }
    }
    return self;
}

-(void)dealloc
{
    vpx_codec_destroy(&codec);
}

-(NSString *)codec
{
    return @"vp8";
}

-(void)encodeFrame:(OGVVideoBuffer *)buffer
{
    vpx_img_fmt_t fmt;
    switch (buffer.format.pixelFormat) {
        case OGVPixelFormatYCbCr420:
            fmt = VPX_IMG_FMT_I420;
            break;
        case OGVPixelFormatYCbCr422:
            fmt = VPX_IMG_FMT_I422;
            break;
        case OGVPixelFormatYCbCr444:
            fmt = VPX_IMG_FMT_I444;
            break;
        default:
            [NSException raise:@"OGVVP8EncoderException"
                        format:@"unexpected pixel format type %d", (int)buffer.format.pixelFormat];
    }

    vpx_image_t img;
    @try {
        vpx_img_alloc(&img, fmt, buffer.format.frameWidth, buffer.format.frameHeight, 16);

        // @fixme do we need to alloc or can we just change the pointers?
        [buffer lock:^() {
            [self copyPlane:buffer.Y image:&img index:0];
            [self copyPlane:buffer.Cb image:&img index:1];
            [self copyPlane:buffer.Cr image:&img index:2];
        }];
        
        // @fixme get correct duration from input data...
        vpx_codec_err_t ret = vpx_codec_encode(&codec,
                                               &img,
                                               buffer.timestamp * 1000 /* timestamp in ms */,
                                               (1000/30) /* approx duration in ms */,
                                               0 /* flags */,
                                               deadline /* deadline in usec or constant */);
        if (ret != VPX_CODEC_OK) {
            
            [NSException raise:@"OGVVP8EncoderException"
                        format:@"vpx_codec_encode returned %d: %s %s", ret, vpx_codec_error(&codec), vpx_codec_error_detail(&codec)];
        }
    } @finally {
        vpx_img_free(&img);
    }

    vpx_codec_iter_t iter = NULL;
    const vpx_codec_cx_pkt_t *pkt;
    while ((pkt = vpx_codec_get_cx_data(&codec, &iter)) != NULL) {
        [self.packets queue:[[OGVPacket alloc] initWithData:[NSData dataWithBytes:pkt->data.frame.buf length:pkt->data.frame.sz]
                                                  timestamp:pkt->data.frame.pts / 1000.0
                                                   duration:pkt->data.frame.duration / 1000.0
                                                   keyframe:(pkt->data.frame.flags & VPX_FRAME_IS_KEY) != 0]];
    }
}

-(void)copyPlane:(OGVVideoPlane *)plane image:(const vpx_image_t *)img index:(size_t)index
{
    for (size_t y = 0; y < plane.lines; y++) {
        memcpy(img->planes[index] + y * img->stride[index],
               plane.data.bytes + y * plane.stride,
               MIN(plane.stride, img->stride[index]));
    }
}

@end
