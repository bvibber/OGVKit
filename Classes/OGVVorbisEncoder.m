//
//  OGVVorbisEncoder.m
//  OGVKit
//
//  Copyright (c) 2016 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"
#import "OGVVorbisEncoder.h"

#include <vorbis/vorbisenc.h>

@implementation OGVVorbisEncoder
{
    vorbis_info vi;
    vorbis_dsp_state v;
    vorbis_comment vc;
    vorbis_block vb;
    
    int64_t lastSample;
    NSArray *_headers;
}

-(instancetype)initWithFormat:(OGVAudioFormat *)format
                      options:(NSDictionary *)options
{
    int ret;

    self = [super initWithFormat:format options:options];
    if (self) {
        int bitrate = ((NSNumber *)options[OGVAudioEncoderOptionsBitrateKey]).integerValue;

        vorbis_info_init(&vi);
        ret = vorbis_encode_init(&vi, format.channels, format.sampleRate, bitrate, bitrate, bitrate);
        if (ret) {
            [NSException raise:@"OGVVorbisEncoderException"
                        format:@"vorbis_encode_init returned %d", ret];
        }

        ret = vorbis_analysis_init(&v, &vi);
        if (ret) {
            [NSException raise:@"OGVVorbisEncoderException"
                        format:@"vorbis_analysis_init returned %d", ret];
        }
        
        vorbis_comment_init(&vc);
        
        ogg_packet op;
        ogg_packet op_comm;
        ogg_packet op_code;
        ret = vorbis_analysis_headerout(&v, &vc, &op, &op_comm, &op_code);
        if (ret) {
            [NSException raise:@"OGVVorbisEncoderException"
                        format:@"vorbis_analysis_headerout returned %d", ret];
        }
        _headers = @[[self oggHeaderPacket:&op],
                     [self oggHeaderPacket:&op_comm],
                     [self oggHeaderPacket:&op_code]];

        ret = vorbis_block_init(&v, &vb);
        if (ret) {
            [NSException raise:@"OGVVorbisEncoderException"
                        format:@"vorbis_block_init returned %d", ret];
        }

        lastSample = 0;
    }
    return self;
}

-(void)dealloc
{
    vorbis_block_clear(&vb);
    vorbis_comment_clear(&vc);
    vorbis_dsp_clear(&v);
    vorbis_info_clear(&vi);
}

-(NSString *)codec
{
    return @"vorbis";
}

-(OGVPacket *)oggHeaderPacket:(ogg_packet *)op
{
    NSData *data = [[NSData alloc] initWithBytes:op->packet length:op->bytes];
    return [[OGVPacket alloc] initWithData:data
                                 timestamp:0
                                  duration:0
                                  keyframe:NO];
}

-(NSArray *)headers
{
    return _headers;
}

-(void)encodeAudio:(OGVAudioBuffer *)buffer
{
    if (![buffer.format isEqual:self.format]) {
        [NSException raise:@"OGVVorbisEncoderException"
                    format:@"buffer doesn't match stream format"];
    }

    float **ab = vorbis_analysis_buffer(&v, buffer.samples);
    if (!ab) {
        [NSException raise:@"OGVVorbisEncoderException"
                    format:@"vorbis_analysis_buffer returned NULL"];
    }

    for (int i = 0; i < buffer.format.channels; i++) {
        memcpy([buffer PCMForChannel:i], ab[i], buffer.samples * sizeof(float));
    }
    
    int ret = vorbis_analysis_wrote(&v, buffer.samples);
    if (ret) {
        [NSException raise:@"OGVVorbisEncoderException"
                    format:@"vorbis_analysis_wrote returned %d", ret];
    }
    
    [self vorbisPacketOut];
}

-(void)close
{
    int ret = vorbis_analysis_wrote(&v, 0);
    if (ret) {
        [NSException raise:@"OGVVorbisEncoderException"
                    format:@"final vorbis_analysis_wrote returned %d", ret];
    }
    
    [self vorbisPacketOut];
}

-(void)vorbisPacketOut
{
    int ret;
    
    BOOL moreBlocks;
    do {
        ret = vorbis_analysis_blockout(&v, &vb);
        if (ret < 0) {
            [NSException raise:@"OGVVorbisEncoderException"
                        format:@"vorbis_analysis_blockout returned %d", ret];
        }
        BOOL moreBlocks = (ret > 0);
        
        ret = vorbis_analysis(&vb, NULL);
        if (ret) {
            [NSException raise:@"OGVVorbisEncoderException"
                        format:@"vorbis_analysis returned %d", ret];
        }
        
        ret = vorbis_bitrate_addblock(&vb);
        if (ret) {
            [NSException raise:@"OGVVorbisEncoderException"
                        format:@"vorbis_bitrate_addblock returned %d", ret];
        }
        
        ogg_packet op;
        BOOL morePackets;
        do {
            ret = vorbis_bitrate_flushpacket(&v, &op);
            if (ret < 0) {
                [NSException raise:@"OGVVorbisEncoderException"
                            format:@"vorbis_bitrate_flushpacket returned %d", ret];
            }
            morePackets = (ret > 0);
            
            NSData *data = [[NSData alloc] initWithBytes:op.packet length:op.bytes];
            
            int64_t endSample = op.granulepos;
            int64_t startSample = lastSample;
            int64_t samples = endSample - startSample;
            lastSample = endSample;
            
            OGVPacket *packet = [[OGVPacket alloc] initWithData:data
                                                      timestamp:startSample / self.format.sampleRate
                                                       duration:samples / self.format.sampleRate
                                                       keyframe:YES];
            [self.packets queue:packet];
        } while (morePackets);
    } while (moreBlocks);
}

@end
