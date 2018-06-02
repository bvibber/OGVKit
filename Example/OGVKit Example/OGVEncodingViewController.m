//
//  OGVEncodingViewController.m
//  OGVKit Example
//
//  Created by Brion on 2/2/17.
//  Copyright © 2017 Brion Vibber. All rights reserved.
//

#import "OGVEncodingViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface OGVEncodingViewController ()

@end

@implementation OGVEncodingViewController
{
    NSURL *inputURL;
    NSURL *outputURL;
    NSDate *startTime;
    NSDate *endTime;
    int frameCount;
    int bitrate;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.transcodeButton.enabled = NO;
    self.transcodeProgress.progress = 0.0f;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/


- (IBAction)chooserAction:(id)sender
{
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        NSLog(@"no photo library permission?");
        return;
    }
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.mediaTypes = @[(__bridge id)kUTTypeMovie];
    if (@available(iOS 11.0, *)) {
        // AVAssetExportPreset640x480
        // AVAssetExportPreset960x540
        // AVAssetExportPreset1280x720
        // AVAssetExportPreset1920x1080
        // AVAssetExportPreset3840x2160
        // AVAssetExportPresetHEVC1920x1080
        // AVAssetExportPresetHEVC3840x2160
        // AVAssetExportPresetPassthrough
        switch (self.resolutionSelector.selectedSegmentIndex) {
            case 0:
                picker.videoExportPreset = AVAssetExportPreset640x480;
                break;
            case 1:
                picker.videoExportPreset = AVAssetExportPreset1280x720;
                break;
            case 2:
                picker.videoExportPreset = AVAssetExportPreset1920x1080;
                break;
            default:
                picker.videoExportPreset = AVAssetExportPresetPassthrough;
        }
    } else {
        // Can't pre-select the resolution on iOS 10 and below?
    }

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        picker.modalPresentationStyle = UIModalPresentationPopover;
    }
    [self presentViewController:picker animated:YES completion:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UIPopoverPresentationController *pop = [picker popoverPresentationController];
        pop.sourceView = sender;
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
{
    [picker dismissViewControllerAnimated:YES completion:nil];

    inputURL = info[UIImagePickerControllerMediaURL];
    outputURL = nil;
    
    self.inputPlayer.sourceURL = inputURL;
    
    self.transcodeButton.enabled = YES;
    self.transcodeProgress.progress = 0.0f;
}

- (IBAction)transcodeAction:(id)sender
{
    self.chooserButton.enabled = NO;
    self.transcodeButton.enabled = NO;
    self.transcodeProgress.progress = 0.0f;
    
    OGVMediaType *mp4 = [[OGVMediaType alloc] initWithString:@"video/mp4"];
    OGVDecoder *decoder = [[OGVKit singleton] decoderForType:mp4];
    decoder.inputStream = [OGVInputStream inputStreamWithURL:inputURL];

    startTime = [NSDate date];
    frameCount = 0;
    endTime = nil;
    bitrate = [self selectBitrate];

    dispatch_queue_t transcodeThread = dispatch_queue_create("Example.transcode", NULL);
    dispatch_async(transcodeThread, ^() {
        while (!decoder.dataReady) {
            if (![decoder process]) {
                [NSException raise:@"ExampleException"
                            format:@"failed before data ready?"];
            }
        }
        while ((decoder.hasAudio && !decoder.audioReady) || (decoder.hasVideo && !decoder.frameReady)) {
            // hack to make sure found packets
            [decoder process];
        }
        
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"output.webm"];
        OGVFileOutputStream *outputStream = [[OGVFileOutputStream alloc] initWithPath:path];

        OGVMediaType *webm = [[OGVMediaType alloc] initWithString:@"video/webm"];
        OGVEncoder *encoder = [[OGVEncoder alloc] initWithMediaType:webm];
        [encoder openOutputStream:outputStream];
        [encoder addVideoTrackFormat:decoder.videoFormat
                             options:@{OGVVideoEncoderOptionsBitrateKey:@(bitrate),
                                       OGVVideoEncoderOptionsKeyframeIntervalKey: @150,
                                       OGVVideoEncoderOptionsSpeedKey: @4}];
        [encoder addAudioTrackFormat:decoder.audioFormat
                             options:@{OGVAudioEncoderOptionsBitrateKey:@128000}];
        
        float total = decoder.duration;
        float lastTime = 0.0f;

        while (decoder.frameReady || decoder.audioReady) {
            BOOL doVideo = NO, doAudio = NO;

            if (decoder.frameReady && decoder.audioReady) {
                if (decoder.audioTimestamp <= decoder.frameTimestamp) {
                    lastTime = decoder.audioTimestamp;
                    doAudio = YES;
                } else {
                    lastTime = decoder.frameTimestamp;
                    doVideo = YES;
                }
            } else if (decoder.frameReady) {
                lastTime = decoder.frameTimestamp;
                doVideo = YES;
            } else if (decoder.audioReady) {
                lastTime = decoder.audioTimestamp;
                doAudio = YES;
            }

            float percent = lastTime / total;
            dispatch_async(dispatch_get_main_queue(), ^() {
                self.transcodeProgress.progress = percent;
            });
            if (doVideo) {
                [decoder decodeFrameWithBlock:^(OGVVideoBuffer *frameBuffer) {
                    [encoder encodeFrame:frameBuffer];

                    self->frameCount++;
                    if (self->frameCount % 100 == 0) {
                        [OGVKit.singleton.logger debugWithFormat:@"%0.2f fps",
                            (float)self->frameCount / [[NSDate date] timeIntervalSinceDate:self->startTime]];
                    }
                }];
            } else if (doAudio) {
                [decoder decodeAudioWithBlock:^(OGVAudioBuffer *audioBuffer) {
                    [encoder encodeAudio:audioBuffer];
                }];
            }
            while ((decoder.hasAudio && !decoder.audioReady) || (decoder.hasVideo && !decoder.frameReady)) {
                if (![decoder process]) {
                    break;
                }
            }
        }
        NSLog(@"done");
        
        [encoder close];
        
        dispatch_async(dispatch_get_main_queue(), ^() {
            NSLog(@"playing %@", path);
            self.transcodeProgress.progress = 1.0;
            
            float fps = (float)self->frameCount / [[NSDate date] timeIntervalSinceDate:self->startTime];
            self.fpsLabel.text = [NSString stringWithFormat:@"%0.2f fps", fps];

            NSError *err;
            unsigned long long size = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:&err] fileSize];
            float mbits = ((float)size * 8.0 / 1000000.0) / decoder.duration;
            self.mbitsLabel.text = [NSString stringWithFormat:@"%0.2f Mbits", mbits];

            self.chooserButton.enabled = YES;
            self.outputPlayer.sourceURL = [NSURL fileURLWithPath:path];
            [self.outputPlayer play];
        });
    });
}

-(int)selectBitrate
{
    switch (self.resolutionSelector.selectedSegmentIndex) {
        case 0:
            return 2000000; // 480p @ 2 megabits -> lots of headroom
        case 1:
            return 4000000; // 720p @ 4 megabits -> lots of headroom
        case 2:
            return 8000000; // 1080p @ 8 megabits -> lots of headroom
        default:
            return 8000000;
    }
}

@end
