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
@property (nonatomic, strong) UIImageView *imageView2;
@property (nonatomic, assign) BOOL showImage;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupCoreMLModel];
    [self setupSession];
    [self runSession];
    
    
    [self.view addSubview:self.imageView2];
    [self.view addSubview:self.imageView];
    [self.view addSubview:self.button];
    
    // Do any additional setup after loading the view, typically from a nib.
}

- (UIImageView *)imageView;
{
    if (!_imageView){
        _imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
        _imageView.hidden = YES;
        _imageView.alpha = 0.5;
        _imageView.contentMode = UIViewContentModeScaleToFill;
    }
    return _imageView;
}

- (UIImageView *)imageView2;
{
    if (!_imageView2){
        _imageView2 = [[UIImageView alloc] initWithFrame:self.view.bounds];
        _imageView2.hidden = YES;
        _imageView2.contentMode = UIViewContentModeScaleToFill;
    }
    return _imageView2;
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
        self.imageView.image = nil;
        self.imageView2.image = nil;
    }
    else {
        [self.session startRunning];
    }
    self.imageView.hidden = !self.imageView.hidden;
    self.imageView2.hidden = !self.imageView2.hidden;
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error;
{
    [self.session stopRunning];
    NSData *data = [photo fileDataRepresentation];
    UIImage *image = [UIImage imageWithData:data];
    UIImage * portraitImage = [[UIImage alloc] initWithCGImage: image.CGImage
                                                         scale: 1.0
                                                   orientation: UIImageOrientationRight];
    NSTimeInterval startTime = CACurrentMediaTime();
    UIImage *retImage = [self predictImageScene:portraitImage];
    NSLog(@"total cost; %f", CACurrentMediaTime() - startTime);
    
}

- (UIImage *)predictImageScene:(UIImage *)image {
//    image = [UIImage imageNamed:@"test.png"];
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
    [[UIColor colorWithRed:1 green:1 blue:1 alpha:0] setFill];
    UIRectFill(CGRectMake(0, 0, size.width, size.height));
    [[UIColor redColor] setFill];
    
    
    NSTimeInterval startTime2 = CACurrentMediaTime();
    float ratio = 1.0/8;
    for (int i = 0; i < len; ++i) {
        for (int j = 0; j < len; ++j) {
            float sourceI = (i + 0.5) * ratio - 0.5;
            float sourceJ = (j + 0.5) * ratio - 0.5;
            int i0 = sourceI;
            int j0 = sourceJ;
            
            float ratioX = sourceI - i0;
            float ratioY = sourceJ - j0;
            
            int i1 = i0+1;
            int j1 = j0+1;
            j1 = j1 >= len/8 ? len/8 - 1: j1;
            i1 = i1 >= len/8 ? len/8 - 1: i1;
            
            
            int maxIdx = 0;
            double maxProp = 0;
//            NSLog(@"%d %d %d %d", i0, i1, j0, j1);
            for (int k = 0; k < classNum; ++k) {
                //计算双线性差值
                float valueI0 = p[[self calIdxWithI:i0 J:j0 K:k Len:len] ]*(1-ratioY) + p[[self calIdxWithI:i0 J:j1 K:k Len:len]]*ratioY;
                float valueI1 = p[[self calIdxWithI:i1 J:j0 K:k Len:len] ]*(1-ratioY) + p[[self calIdxWithI:i1 J:j1 K:k Len:len]]*ratioY;
                float prop = valueI0*(1-ratioX) + valueI1*ratioX;
                if (k == 0) {
                    maxIdx = 0;
                    maxProp = prop;
                } else {
                    if (maxProp < prop) {
                        maxProp = prop;
                        maxIdx = k;
                    }
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
    
    self.imageView.image = retImage;
    self.imageView2.image = scaledImage;
    
    return retImage;
}

- (NSUInteger)calIdxWithI:(NSUInteger)i J:(NSUInteger)j K:(NSUInteger)k Len:(NSUInteger)len;
{
    len /= 8;
    NSUInteger ret = i + j*len + k*len*len;
    return ret;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
