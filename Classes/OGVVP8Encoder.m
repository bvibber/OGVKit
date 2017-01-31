//
//  OGVVP8Encoder
//  OGVKit
//
//  Copyright (c) 2016 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"
#import "OGVVP8Encoder.h"

#define VPX_CODEC_DISABLE_COMPAT 1
#include <VPX/vpx/vpx_encoder.h>
#include <VPX/vpx/vp8cx.h>

@implementation OGVVP8Encoder
{
    vpx_codec_ctx_t codec;
}

-(instancetype)initWithFormat:(OGVVideoFormat *)format options:(NSDictionary *)options
{
    self = [self initWithFormat:format options:options];
    if (self) {
        vpx_codec_iface_t *encoderInterface = vpx_codec_vp8_cx();

        vpx_codec_enc_cfg_t cfg;
        vpx_codec_enc_config_default(encoderInterface, &cfg, 0);
        cfg.g_w = format.frameWidth;
        cfg.g_h = format.frameHeight;
        cfg.g_timebase.num = 1;
        cfg.g_timebase.den = 1000;

        NSNumber *bitrate = options[OGVVideoEncoderOptionsBitrateKey];
        if (bitrate) {
            cfg.rc_target_bitrate = bitrate.integerValue;
        }

        vpx_codec_enc_init(&codec, encoderInterface, &cfg, 0);
    }
    return self;
}

-(void)dealloc
{
    //
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
                        format:@"unexpected pixel format type %d", buffer.format.pixelFormat];
    }

    vpx_image_t img;
    @try {
        vpx_img_alloc(&img, fmt, buffer.format.frameWidth, buffer.format.frameHeight, 16);

        [self copyPlane:buffer.Y image:&img index:0];
        [self copyPlane:buffer.Cb image:&img index:1];
        [self copyPlane:buffer.Cr image:&img index:2];
        
        vpx_codec_err_t ret = vpx_codec_encode(&codec, &img, buffer.timestamp * 1000, buffer.duration * 1000, 0, 0);
        if (ret != VPX_CODEC_OK) {
            [NSException raise:@"OGVVP8EncoderException"
                        format:@"vpx_codec_encode returned %d", ret];
        }
    } @finally {
        vpx_img_free(&img);
    }

    OGVPacket *packet = nil;

    vpx_codec_iter_t iter = NULL;
    vpx_codec_cx_pkt_t *pkt;
    while ((pkt = vpx_codec_get_cx_data(&codec, &iter)) != NULL) {
        [self.packets queue:[[OGVPacket alloc] initWithData:[NSData dataWithBytes:pkt->data.frame.buf length:pkt->data.frame.sz]
                                                  timestamp:pkt->data.frame.pts / 1000.0
                                                   duration:pkt->data.frame.duration / 1000.0]];
    }
}

-(void)copyPlane:(OGVVideoPlane *)plane image:(vpx_image_t *)img index:(size_t)index
{
    for (size_t y = 0; y < plane.lines; y++) {
        memcpy(plane.data.bytes + y * plane.stride,
               img->planes[index] + y * img->stride[index],
               MIN(plane.stride, img->stride[index]));
    }
}

@end
