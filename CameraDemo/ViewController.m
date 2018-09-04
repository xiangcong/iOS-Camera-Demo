//
//  ViewController.m
//  CameraDemo
//
//  Created by jingjinzhou on 29/5/18.
//  Copyright © 2018年 jingjinzhou. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "DeeplabMobilenet.h"
#import "UIImage+Utils.h"


const int len = 512;
const int classNum = 21;

@interface ViewController () <AVCapturePhotoCaptureDelegate>
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDevice *device;
@property (nonatomic, strong) AVCaptureInput *input;
@property (nonatomic, strong) AVCapturePhotoOutput *output;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) UIButton *button;
@property (nonatomic, strong) DeeplabMobilenet* model;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, assign) BOOL showImage;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupCoreMLModel];
    [self setupSession];
    [self runSession];
    
    self.imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.imageView];
    self.imageView.hidden = YES;
    [self.view addSubview:self.button];
    
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)setupCoreMLModel;
{
    _model = [[DeeplabMobilenet alloc] init];
}

- (void)setupSession;
{
    
    self.session = [[AVCaptureSession alloc] init];
    self.device =  [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    NSError *error;
    
    [self.session beginConfiguration];
    self.session.sessionPreset = AVCaptureSessionPresetHigh;
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
        _button = [[UIButton alloc] initWithFrame:CGRectMake(width/2 - 60/2, height - 60, 60, 35)];
        _button.backgroundColor = [UIColor blueColor];
        [_button addTarget:self action:@selector(takePhoto) forControlEvents:UIControlEventTouchUpInside];
    }
    return _button;
}



- (void)takePhoto;
{
    if (self.imageView.hidden) {
    
        NSDictionary *dict = @{@"AVVideoCodecKey": AVVideoCodecTypeJPEG};

        AVCapturePhotoSettings *setting = [AVCapturePhotoSettings photoSettingsWithFormat:dict];
        [self.output capturePhotoWithSettings:setting delegate:self];
    }
    else {
        
    }
    self.imageView.hidden = !self.imageView.hidden;
    
    
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error;
{
    NSData *data = [photo fileDataRepresentation];
    UIImage *image = [UIImage imageWithData:data];
    UIImage * portraitImage = [[UIImage alloc] initWithCGImage: image.CGImage
                                                         scale: 1.0
                                                   orientation: UIImageOrientationRight];
    UIImage *retImage = [self predictImageScene:portraitImage];
    self.imageView.image = retImage;
    
}

- (UIImage *)predictImageScene:(UIImage *)image {
    UIImage *scaledImage = [image scaleToSize:CGSizeMake(len, len)];
    CVPixelBufferRef buffer = [image pixelBufferFromCGImage:scaledImage];
    DeeplabMobilenetInput *input = [[DeeplabMobilenetInput alloc] initWithInput_1:buffer];
    NSTimeInterval startTime = CACurrentMediaTime();
    DeeplabMobilenetOutput *output = [self.model predictionFromFeatures:input error:NULL];
    NSLog(@"cost time of coreML: %f", CACurrentMediaTime() - startTime);
    MLMultiArray *array = output.bilinear_upsampling_2; //classNum * len * len
    double *p = (double *)array.dataPointer;
    
    CGSize size = CGSizeMake(len, len);
    UIGraphicsBeginImageContextWithOptions(size, YES, 0);
    [[UIColor whiteColor] setFill];
    UIRectFill(CGRectMake(0, 0, size.width, size.height));
    [[UIColor blackColor] setFill];
    
    
    NSTimeInterval startTime2 = CACurrentMediaTime();
    for (int i = 0; i < len; ++i) {
        for (int j = 0; j < len; ++j) {
            int maxIdx = 0;
            float maxProp = p[i + j*len];
            for (int k = 1; k < classNum; ++k) {
                NSUInteger idx = i + j*len + k*len*len;
                double prop = p[idx];
                if (maxProp < prop) {
                    maxProp = prop;
                    maxIdx = k;
                }
            }
            if (maxIdx == 15) {
                UIRectFill(CGRectMake(i, j, 1, 1));
            }
        }
    }
    NSLog(@"cost time of loop: %f", CACurrentMediaTime() - startTime2);
    
    UIImage *retImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return retImage;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
