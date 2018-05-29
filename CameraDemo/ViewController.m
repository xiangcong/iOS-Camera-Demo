//
//  ViewController.m
//  CameraDemo
//
//  Created by jingjinzhou on 29/5/18.
//  Copyright © 2018年 jingjinzhou. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController () <AVCapturePhotoCaptureDelegate>
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDevice *device;
@property (nonatomic, strong) AVCaptureInput *input;
@property (nonatomic, strong) AVCapturePhotoOutput *output;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) UIButton *button;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupSession];
    [self runSession];
    
    [self.view addSubview:self.button];
    
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)setupSession;
{
    
    self.session = [[AVCaptureSession alloc] init];
    self.device =  [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    NSError *error;
    
    [self.session beginConfiguration];
    self.session.sessionPreset = AVCaptureSessionPresetPhoto;
    self.input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:&error];
    if ([self.session canAddInput:self.input]) {
        [self.session addInput:self.input];
    } else {
        NSLog(@"!error, cannot add input");
    }
    self.output = [[AVCapturePhotoOutput alloc] init];
    if ([self.session canAddOutput:self.output]) {
        [self.session addOutput:self.output];
    } else {
        NSLog(@"!error, cannot add output");
    }
    [self.session commitConfiguration];
    
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    self.previewLayer.frame = [self.view bounds];
    [self.view.layer addSublayer:self.previewLayer];
    
}

- (void)runSession;
{
    [self.session startRunning];
}

- (UIButton *)button;
{
    if (!_button) {
        float width = self.view.bounds.size.width;
        float height = self.view.bounds.size.height;
        _button = [[UIButton alloc] initWithFrame:CGRectMake(width/2 - 50/2, height - 60, 50, 30)];
        _button.backgroundColor = [UIColor blueColor];
        [_button addTarget:self action:@selector(takePhoto) forControlEvents:UIControlEventTouchUpInside];
    }
    return _button;
}

- (void)takePhoto;
{
    NSDictionary *dict = @{@"AVVideoCodecKey": AVVideoCodecTypeJPEG};
//    if ([self.output.availableRawPhotoPixelFormatTypes containsObject:[NSNumber numberWithUnsignedInteger:kCVPixelFormatType_14Bayer_RGGB]]) { //
//        NSLog(@"yes");
//    }
    AVCapturePhotoSettings *setting = [AVCapturePhotoSettings photoSettingsWithRawPixelFormatType:kCVPixelFormatType_14Bayer_RGGB processedFormat:dict];
    [self.output capturePhotoWithSettings:setting delegate:self];
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error;
{
    NSData *data = [photo fileDataRepresentation];
    if (photo.isRawPhoto) {
        NSLog(@"caputre dng");
        NSTimeInterval curTime = CACurrentMediaTime();
        NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"/Documents/%f.dng", curTime]];
        [data writeToFile:path atomically:YES];
    } else {
        NSLog(@"caputre jpg");
        NSTimeInterval curTime = CACurrentMediaTime();
        NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"/Documents/%f.jpg", curTime]];
        [data writeToFile:path atomically:YES];
    }
        
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
