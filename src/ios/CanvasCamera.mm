//
//  CanvasCamera.js
//  PhoneGap iOS Cordova Plugin to capture Camera streaming into a HTML5 Canvas or an IMG tag.
//
//  Created by Diego Araos <d@wehack.it> on 12/29/12.
//
//  MIT License

#import "CanvasCamera.hpp"
#import <MobileCoreServices/MobileCoreServices.h>

#import <CoreGraphics/CGImage.h>
#import <opencv2/opencv.hpp>
#import <opencv2/highgui/highgui.hpp>
#import <opencv2/features2d/features2d.hpp>


typedef enum {
    DestinationTypeDataURL = 0,
    DestinationTypeFileURI = 1
}DestinationType;

typedef enum {
    EncodingTypeJPEG = 0,
    EncodingTypePNG = 1
}EncodingType;

#define DATETIME_FORMAT @"yyyy-MM-dd HH:mm:ss"
#define DATE_FORMAT @"yyyy-MM-dd"

// parameter
#define kQualityKey         @"quality"
#define kDestinationTypeKey @"destinationType"
#define kEncodingTypeKey    @"encodingType"


#define kSaveToPhotoAlbumKey     @"saveToPhotoAlbum"
#define kCorrectOrientationKey         @"correctOrientation"

#define kWidthKey        @"width"
#define kHeightKey       @"height"

@interface CanvasCamera () {
    dispatch_queue_t queue;
    BOOL bIsStarted;
    
    // parameters
    AVCaptureFlashMode          _flashMode;
    int          _deepMode;
    AVCaptureDevicePosition     _devicePosition;
    
    // options
    int _quality;
    DestinationType _destType;
    //BOOL _allowEdit;
    EncodingType _encodeType;
    BOOL _saveToPhotoAlbum;
    BOOL _correctOrientation;
    
    int _width;
    int _height;
}

@end

@implementation UIImage (OpenCV)

-(cv::Mat) toMat
{
    CGImageRef imageRef = self.CGImage;
    
    const int srcWidth        = (int)CGImageGetWidth(imageRef);
    const int srcHeight       = (int)CGImageGetHeight(imageRef);
    //const int stride          = CGImageGetBytesPerRow(imageRef);
    //const int bitPerPixel     = CGImageGetBitsPerPixel(imageRef);
    //const int bitPerComponent = CGImageGetBitsPerComponent(imageRef);
    //const int numPixels       = bitPerPixel / bitPerComponent;
    
    CGDataProviderRef dataProvider = CGImageGetDataProvider(imageRef);
    CFDataRef rawData = CGDataProviderCopyData(dataProvider);
    
    //unsigned char * dataPtr = const_cast<unsigned char*>(CFDataGetBytePtr(rawData));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    cv::Mat rgbaContainer(srcHeight, srcWidth, CV_8UC4);
    CGContextRef context = CGBitmapContextCreate(rgbaContainer.data,
                                                 srcWidth,
                                                 srcHeight,
                                                 8,
                                                 4 * srcWidth,
                                                 colorSpace,
                                                 kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big);
    
    CGContextDrawImage(context, CGRectMake(0, 0, srcWidth, srcHeight), imageRef);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    CFRelease(rawData);
    
    cv::Mat t;
    cv::cvtColor(rgbaContainer, t, cv::COLOR_RGBA2BGRA);
    
    //cv::Vec4b a = rgbaContainer.at<cv::Vec4b>(0,0);
    //cv::Vec4b b = t.at<cv::Vec4b>(0,0);
    //std::cout << std::hex << (int)a[0] << " "<< (int)a[1] << " " << (int)a[2] << " "  << (int)a[3] << std::endl;
    //std::cout << std::hex << (int)b[0] << " "<< (int)b[1] << " " << (int)b[2] << " "  << (int)b[3] << std::endl;
    
    return t;
}

+(UIImage*) imageWithMat:(const cv::Mat&) image andDeviceOrientation: (UIDeviceOrientation) orientation
{
    UIImageOrientation imgOrientation = UIImageOrientationUp;
    
    switch (orientation)
    {
        case UIDeviceOrientationLandscapeLeft:
            imgOrientation = UIImageOrientationUp; break;
            
        case UIDeviceOrientationLandscapeRight:
            imgOrientation = UIImageOrientationDown; break;
            
        case UIDeviceOrientationPortraitUpsideDown:
            imgOrientation = UIImageOrientationRightMirrored; break;
            
        default:
        case UIDeviceOrientationPortrait:
            imgOrientation = UIImageOrientationRight; break;
    };
    
    return [UIImage imageWithMat:image andImageOrientation:imgOrientation];
}

+(UIImage*) imageWithMat:(const cv::Mat&) image andImageOrientation: (UIImageOrientation) orientation;
{
    cv::Mat rgbaView;
    
//    if (image.channels() == 3)
//    {
//        cv::cvtColor(image, rgbaView, cv::COLOR_BGR2RGBA);
//    }
//    else if (image.channels() == 4)
//    {
//        cv::cvtColor(image, rgbaView, cv::COLOR_BGRA2RGBA);
//    }
//    else if (image.channels() == 1)
//    {
//        cv::cvtColor(image, rgbaView, cv::COLOR_GRAY2RGBA);
//    }
    rgbaView=image;
//            cv::cvtColor(image, rgbaView, cv::COLOR_GRAY2RGBA);
    
   cvtColor(image, rgbaView, cv::COLOR_BGR2GRAY);
    NSData *data = [NSData dataWithBytes:rgbaView.data length:rgbaView.elemSize() * rgbaView.total()];
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    CGBitmapInfo bmInfo = kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big;
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(image.cols,                                 //width
                                        image.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * image.elemSize(),                       //bits per pixel
                                        image.step.p[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        bmInfo,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef scale:1 orientation:orientation];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}
@end


@implementation CanvasCamera

#pragma mark - Interfaces
+ (UIImage *)resizeImage:(UIImage *)image toSize:(CGSize)newSize
{
    UIGraphicsBeginImageContext(newSize);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    
    return newImage;
}

- (void)startCapture:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult = nil;
    NSString *resultJS = nil;
    //    OrbFeatureDetector detector(500);
    // check already started
    if (self.session && bIsStarted)
    {
        // failure callback
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Already started"];
        resultJS = [pluginResult toErrorCallbackString:command.callbackId];
        [self writeJavascript:resultJS];
        
        return;
    }
    
    // init parameters - default values
    _quality = 10;
    _destType = DestinationTypeDataURL;
    _encodeType = EncodingTypeJPEG;
    _width = 640;
    _height = 480;
    _saveToPhotoAlbum = NO;
    _correctOrientation = YES;
    
    // parse options
    if ([command.arguments count] > 0)
    {
        NSDictionary *jsonData = [command.arguments objectAtIndex:0];
        [self getOptions:jsonData];
    }
    
    // add support for options (fps, capture quality, capture format, etc.)
    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPresetPhoto;//AVCaptureSessionPreset352x288;
    
    self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    self.input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
    
    self.output = [[AVCaptureVideoDataOutput alloc] init];
    self.output.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = @{ AVVideoCodecKey : AVVideoCodecJPEG};
    [self.stillImageOutput setOutputSettings:outputSettings];
    
    
    queue = dispatch_queue_create("canvas_camera_queue", NULL);
    
    [self.output setSampleBufferDelegate:(id)self queue:queue];
    
    [self.session addInput:self.input];
    [self.session addOutput:self.output];
    
    // add still image output
    [self.session addOutput:self.stillImageOutput];
    
    
    [self.session startRunning];
    
    bIsStarted = YES;
    
    
    // success callback
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
    resultJS = [pluginResult toSuccessCallbackString:command.callbackId];
    [self writeJavascript:resultJS];
}

- (void)stopCapture:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult = nil;
    NSString *resultJS = nil;
    
    if (self.session)
    {
        [self.session stopRunning];
        self.session = nil;
        
        bIsStarted = NO;
        
        // success callback
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
        resultJS = [pluginResult toSuccessCallbackString:command.callbackId];
        [self writeJavascript:resultJS];
    }
    else
    {
        bIsStarted = NO;
        
        // failure callback
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Already stopped"];
        resultJS = [pluginResult toErrorCallbackString:command.callbackId];
        [self writeJavascript:resultJS];
    }
}

- (void)setFlashMode:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult = nil;
    NSString *resultJS = nil;
    
    NSString *errMsg = @"";
    BOOL bParsed = NO;
    if (command.arguments.count <= 0)
    {
        bParsed = NO;
        errMsg = @"Please specify a flash mode";
    }
    else
    {
        NSString *strFlashMode = [command.arguments objectAtIndex:0];
        int flashMode = [strFlashMode integerValue];
        if (flashMode != AVCaptureFlashModeOff
            && flashMode != AVCaptureFlashModeOn
            && flashMode != AVCaptureFlashModeAuto)
        {
            bParsed = NO;
            errMsg = @"Invalid parameter";
        }
        else
        {
            _flashMode = flashMode;
            bParsed = YES;
        }
    }
    
    
    if (bParsed)
    {
        BOOL bSuccess = NO;
        // check session is started
        if (bIsStarted && self.session)
        {
            if ([self.device hasTorch] && [self.device hasFlash])
            {
                [self.device lockForConfiguration:nil];
                if (_flashMode == AVCaptureFlashModeOn)
                {
                    [self.device setTorchMode:AVCaptureTorchModeOn];
                    [self.device setFlashMode:AVCaptureFlashModeOn];
                }
                else if (_flashMode == AVCaptureFlashModeOff)
                {
                    [self.device setTorchMode:AVCaptureTorchModeOff];
                    [self.device setFlashMode:AVCaptureFlashModeOff];
                }
                else if (_flashMode == AVCaptureFlashModeAuto)
                {
                    [self.device setTorchMode:AVCaptureTorchModeAuto];
                    [self.device setFlashMode:AVCaptureFlashModeAuto];
                }
                [self.device unlockForConfiguration];
                
                bSuccess = YES;
            }
            else
            {
                bSuccess = NO;
                errMsg = @"This device has no flash or torch";
            }
        }
        else
        {
            bSuccess = NO;
            errMsg = @"Session is not started";
        }
        
        if (bSuccess)
        {
            // success callback
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
            resultJS = [pluginResult toSuccessCallbackString:command.callbackId];
            [self writeJavascript:resultJS];
        }
        else
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errMsg];
            resultJS = [pluginResult toErrorCallbackString:command.callbackId];
            [self writeJavascript:resultJS];
        }
    }
    else
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errMsg];
        resultJS = [pluginResult toErrorCallbackString:command.callbackId];
        [self writeJavascript:resultJS];
    }
}


- (void)setDeepMode:(CDVInvokedUrlCommand *)command
{
    
    CDVPluginResult *pluginResult = nil;
    NSString *resultJS = nil;
    
    NSString *errMsg = @"";
    BOOL bParsed = NO;
    if (command.arguments.count <= 0)
    {
        bParsed = NO;
        errMsg = @"Please specify a deep mode";
    }
    else
    {
        NSString *strDeepMode = [command.arguments objectAtIndex:0];
        int deepMode = [strDeepMode integerValue];
        _deepMode = deepMode;
        bParsed = YES;
    }
    
    
    if (bParsed)
    {
        BOOL bSuccess = NO;
        // check session is started
        if (bIsStarted && self.session)
        {
            bSuccess = YES;
        }
        else
        {
            bSuccess = NO;
            errMsg = @"Session is not started";
        }
        
        if (bSuccess)
        {
            // success callback
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
            resultJS = [pluginResult toSuccessCallbackString:command.callbackId];
            [self writeJavascript:resultJS];
        }
        else
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errMsg];
            resultJS = [pluginResult toErrorCallbackString:command.callbackId];
            [self writeJavascript:resultJS];
        }
    }
    else
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errMsg];
        resultJS = [pluginResult toErrorCallbackString:command.callbackId];
        [self writeJavascript:resultJS];
    }
}

- (void)setCameraPosition:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult = nil;
    NSString *resultJS = nil;
    
    NSString *errMsg = @"";
    BOOL bParsed = NO;
    if (command.arguments.count <= 0)
    {
        bParsed = NO;
        errMsg = @"Please specify a device position";
    }
    else
    {
        NSString *strDevicePosition = [command.arguments objectAtIndex:0];
        int devicePosition = [strDevicePosition integerValue];
        if (devicePosition != AVCaptureFlashModeOff
            && devicePosition != AVCaptureFlashModeOn
            && devicePosition != AVCaptureFlashModeAuto)
        {
            bParsed = NO;
            errMsg = @"Invalid parameter";
        }
        else
        {
            _devicePosition = devicePosition;
            bParsed = YES;
        }
    }
    
    if (bParsed)
    {
        //Change camera source
        if(self.session)
        {
            //Remove existing input
            AVCaptureInput* currentCameraInput = [self.session.inputs objectAtIndex:0];
            if(((AVCaptureDeviceInput*)currentCameraInput).device.position != _devicePosition)
            {
                //Indicate that some changes will be made to the session
                [self.session beginConfiguration];
                
                //Remove existing input
                AVCaptureInput* currentCameraInput = [self.session.inputs objectAtIndex:0];
                [self.session removeInput:currentCameraInput];
                
                //Get new input
                AVCaptureDevice *newCamera = nil;
                
                newCamera = [self cameraWithPosition:_devicePosition];
                
                //Add input to session
                AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:newCamera error:nil];
                [self.session addInput:newVideoInput];
                
                //Commit all the configuration changes at once
                [self.session commitConfiguration];
                
                // success callback
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
                resultJS = [pluginResult toSuccessCallbackString:command.callbackId];
                [self writeJavascript:resultJS];
            }
            else
            {
                // success callback
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
                resultJS = [pluginResult toSuccessCallbackString:command.callbackId];
                [self writeJavascript:resultJS];
            }
            
            
        }
        else
        {
            errMsg = @"Capture stopped";
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errMsg];
            resultJS = [pluginResult toErrorCallbackString:command.callbackId];
            [self writeJavascript:resultJS];
        }
        
        
    }
    else
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errMsg];
        resultJS = [pluginResult toErrorCallbackString:command.callbackId];
        [self writeJavascript:resultJS];
    }
}

- (void)setCentroid:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult = nil;
    NSString *resultJS = nil;
    
    NSString *errMsg = @"";
    BOOL bParsed = NO;
    if (command.arguments.count <= 0)
    {
        bParsed = NO;
        errMsg = @"Please specify a device position";
    }
    else
    {
        NSString *c = [command.arguments objectAtIndex:0];
        
        NSLog(@"fooo %@",c);
    }
    
}

- (void)captureImage:(CDVInvokedUrlCommand *)command
{
    NSLog(@"ccccc, this is a native function called from PhoneGap/Cordova!");
    __block CDVPluginResult *pluginResult = nil;
    __block NSString *resultJS = nil;
    
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in self.stillImageOutput.connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) { break; }
    }
    
    // Find out the current orientation and tell the still image output.
    AVCaptureConnection *stillImageConnection = videoConnection;//[self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
    AVCaptureVideoOrientation avcaptureOrientation = [self avOrientationForDeviceOrientation:curDeviceOrientation];
    [stillImageConnection setVideoOrientation:avcaptureOrientation];
    
    // set the appropriate pixel format / image type output setting depending on if we'll need an uncompressed image for
    // the possiblity of drawing the red square over top or if we're just writing a jpeg to the camera roll which is the trival case
    [self.stillImageOutput setOutputSettings:[NSDictionary dictionaryWithObject:AVVideoCodecJPEG
                                                                         forKey:AVVideoCodecKey]];
    
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:stillImageConnection
                                                       completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
                                                           if (error) {
                                                               //[self displayErrorOnMainQueue:error withMessage:@"Take picture failed"];
                                                           }
                                                           else {
#if 0
                                                               // trivial simple JPEG case
                                                               NSData *jpegData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                                                               CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault,
                                                                                                                           imageDataSampleBuffer,
                                                                                                                           kCMAttachmentMode_ShouldPropagate);
                                                               ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
                                                               [library writeImageDataToSavedPhotosAlbum:jpegData metadata:(__bridge id)attachments completionBlock:^(NSURL *assetURL, NSError *error) {
                                                                   if (error) {
                                                                       [self.commandDelegate runInBackground:^{
                                                                           //[self displayErrorOnMainQueue:error withMessage:@"Save to camera roll failed"];
                                                                           pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"Writing data to asset failed :%@", [error localizedDescription]]];
                                                                           [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                                                                       }];
                                                                   }
                                                                   else
                                                                   {
                                                                       [self.commandDelegate runInBackground:^{
                                                                           // success callback
                                                                           pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
                                                                           [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                                                                       }];
                                                                   }
                                                               }];
                                                               
                                                               if (attachments)
                                                                   CFRelease(attachments);
                                                               //[library release];
#else
                                                               // when processing an existing frame we want any new frames to be automatically dropped
                                                               // queueing this block to execute on the videoDataOutputQueue serial queue ensures this
                                                               // see the header doc for setSampleBufferDelegate:queue: for more information
                                                               dispatch_sync(queue, ^(void) {
                                                                   
                                                                   NSData *jpegData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                                                                   
                                                                   // save image to camera roll
                                                                   if (_saveToPhotoAlbum)
                                                                   {
                                                                       CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault,
                                                                                                                                   imageDataSampleBuffer,
                                                                                                                                   kCMAttachmentMode_ShouldPropagate);
                                                                       [self writeJPGToCameraRoll:jpegData withAttachments:attachments];
                                                                       if (attachments)
                                                                           CFRelease(attachments);
                                                                   }
                                                                   
                                                                   UIImage *srcImg = [UIImage imageWithData:jpegData];
                                                                   UIImage *resizedImg = [CanvasCamera resizeImage:srcImg toSize:CGSizeMake(_width, _height)];
                                                                   
                                                                   
                                                                   BOOL bRet = NO;
                                                                   NSMutableDictionary *dicRet = [[NSMutableDictionary alloc] init];
                                                                   
                                                                   // type
                                                                   NSString *type = (_encodeType == EncodingTypeJPEG)?@"image/jpeg":@"image/png";
                                                                   [dicRet setObject:type forKey:@"type"];
                                                                   
                                                                   // lastModifiedDate
                                                                   NSDate *currDate = [NSDate date];
                                                                   NSString *lastModifiedDate = [CanvasCamera date2str:currDate withFormat:DATETIME_FORMAT];
                                                                   [dicRet setObject:lastModifiedDate forKey:@"lastModifiedDate"];
                                                                   
                                                                   
                                                                   
                                                                   
                                                                   
                                                                   
                                                                   
                                                                   
                                                                   
                                                                   
                                                                   
                                                                   
                                                                   
                                                                   
                                                                   
                                                                   
                                                                   //imageURI
                                                                   NSData *data = nil;
                                                                   if (_encodeType == EncodingTypeJPEG)
                                                                       data = UIImageJPEGRepresentation(resizedImg, (_quality / 10.0));
                                                                   else
                                                                       data = UIImagePNGRepresentation(resizedImg);
                                                                   if (_destType == DestinationTypeFileURI)
                                                                   {
                                                                       // save resized image to app space
                                                                       NSString *path = [CanvasCamera getFilePath:[CanvasCamera GetUUID] ext:(_encodeType == EncodingTypeJPEG)?@"jpg":@"png"];
                                                                       
                                                                       bRet = [self writeData:data toPath:path];
                                                                       
                                                                       [dicRet setObject:path forKey:@"imageURI"];
                                                                   }
                                                                   else
                                                                   {
                                                                       // Convert to Base64 data
                                                                       NSData *base64Data = [data base64EncodedDataWithOptions:0];
                                                                       NSString *strData = [NSString stringWithUTF8String:(const char *)[base64Data bytes]];
                                                                       
                                                                       [dicRet setObject:strData forKey:@"imageURI"];
                                                                   }
                                                                   
                                                                   // size
                                                                   [dicRet setObject:[NSString stringWithFormat:@"%d", (int)data.length] forKey:@"size"];
                                                                   
                                                                   
                                                                   if (bRet == NO)
                                                                   {
                                                                       [self.commandDelegate runInBackground:^{
                                                                           //[self displayErrorOnMainQueue:error withMessage:@"Save to camera roll failed"];
                                                                           pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"Writing data failed"]];
                                                                           [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                                                                       }];
                                                                   }
                                                                   else
                                                                   {
                                                                       [self.commandDelegate runInBackground:^{
                                                                           // success callback
                                                                           pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dicRet];
                                                                           [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                                                                       }];
                                                                   }
                                                                   
                                                               });
#endif
                                                           }
                                                       }
     ];
}

#pragma mark - capture delegate
NSInteger itr=0;

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    @autoreleasepool {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CVPixelBufferLockBaseAddress(imageBuffer,0);
        uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        
        CGImageRef newImage = CGBitmapContextCreateImage(newContext);
        
        CGContextRelease(newContext);
        CGColorSpaceRelease(colorSpace);
        
        UIImage *image = [UIImage imageWithCGImage:newImage];
        
        // resize image
        //image = [CanvasCamera resizeImage:image toSize:CGSizeMake(352.0, 288.0)];
        
        //image = [CanvasCamera resizeImage:image toSize:CGSizeMake(width/10, height/10)];
        //        image = [CanvasCamera resizeImage:image toSize:CGSizeMake(width, height)];
        
                image = [CanvasCamera resizeImage:image toSize:CGSizeMake(width, height)];
//                image = [CanvasCamera resizeImage:image toSize:CGSizeMake(width/2, height/2)];
        
        //        image = [CanvasCamera resizeImage:image toSize:CGSizeMake(width/4, height/4)];
        
        itr++;
//                NSLog(@"%d",itr);
        
        
        
        cv::Mat src_img;
        src_img=[image toMat];
        //    cv::UIImageToMat(newImage, src_img);
        
        cv::Mat gray_img;
         gray_img=src_img;
//        cv::transform(src_img, gray_img, 50);
        cvtColor(src_img, gray_img, cv::COLOR_BGR2GRAY);
        
        
        cv::Mat edges;
        cv::Mat outputFrame;
//        , m_harrisBlockSize(2)
//        , m_harrisapertureSize(3)
//        , m_harrisK(0.04f)
//        , m_harrisThreshold(200)
//                int m_cannyLoThreshold=250;
//                int m_cannyHiThreshold=250;
//                int m_cannyAperture=1;
//        cv::Canny(gray_img, edges, m_cannyLoThreshold, m_cannyHiThreshold, m_cannyAperture * 2 + 1);
        
        int scale = 1;
        int delta = 0;
        int ddepth = CV_16S;
        
        cv::Mat grad_x, grad_y;
        cv::Mat abs_grad_x, abs_grad_y;
        
        if(_deepMode==0){
        /// Gradient X
        cv::Sobel( gray_img, grad_x, ddepth, 1, 0, 3, scale, delta, cv::BORDER_DEFAULT );
        cv::convertScaleAbs( grad_x, abs_grad_x );
        
        /// Gradient Y
        cv::Sobel( gray_img, grad_y, ddepth, 0, 1, 3, scale, delta, cv::BORDER_DEFAULT );
        cv::convertScaleAbs( grad_y, abs_grad_y );
        
        /// Total Gradient (approximate)
        cv::addWeighted( abs_grad_x, 0.5, abs_grad_y, 0.5, 0, edges );
        
        }else{
            
            int scale = 1;
            int delta = 0;
            int ddepth = CV_16S;
            
            /// Gradient X
            cv::Scharr( gray_img, grad_x, ddepth, 1, 0, scale, delta, cv::BORDER_DEFAULT );
            cv::convertScaleAbs( grad_x, abs_grad_x );
            
            /// Gradient Y
            cv::Scharr( gray_img, grad_y, ddepth, 0, 1, scale, delta, cv::BORDER_DEFAULT );
            cv::convertScaleAbs( grad_y, abs_grad_y );
            
            /// Total Gradient (approximate)
            cv::addWeighted( abs_grad_x, 0.5, abs_grad_y, 0.5, 0, edges );
        }
        edges= ~edges;
        cv::cvtColor(edges, outputFrame, cv::COLOR_GRAY2BGRA);
        gray_img=outputFrame;
        
        
//        cv::Mat grayImage;
//        cv::Mat edges;
//    
//        cv::Mat grad_x, grad_y;
//        cv::Mat abs_grad_x, abs_grad_y;
//        
//        cv::Mat dst;
//        cv::Mat dst_norm, dst_norm_scaled;
//        
//        bool m_showOnlyEdges;
//        std::string m_algorithmName;
//        
//        // Canny detector options:
//        int m_cannyLoThreshold;
//        int m_cannyHiThreshold;
//        int m_cannyAperture;
//        
//        // Harris detector options:
//        int m_harrisBlockSize;
//        int m_harrisapertureSize;
//        double m_harrisK;
//        int m_harrisThreshold;
        
        
        
        
//        cv::cvtColor(src_img, gray_img, cv::COLOR_BGRA2RGBA);
        std::vector<cv::KeyPoint> objectKeypoints;
        std::vector<cv::KeyPoint> keypoints;
        cv::Mat descriptors;
        cv::OrbFeatureDetector detector(400);
        detector.detect(gray_img, keypoints);
        detector.compute(gray_img, keypoints, descriptors);
//        std::cout <<descriptors.rows;
//        std::ofstream ofs();
//                int nec=descriptors.at<int>(0,0);
//        std::cout << descriptors << std::endl;
//        NSString *abc;
//        for(int i = 0; i < descriptors.rows; i++)
//        {
//            for(int j = 0; j < descriptors.cols; j++)
//            {
//                int bgrPixel = descriptors.at<int>(i, j);
//                abc = [NSString stringWithFormat:@"%@ %d",abc,bgrPixel];
//                // do something with BGR values...
//            }
//        }
//        NSLog(@" %d %d",gray_img.rows,gray_img.cols);
//        NSLog(@" %d %d",descriptors.rows,descriptors.cols);
//        NSLog(abc);
//        NSString *desc=[[descriptors valueForKey:@"abc"]  componentsJoinedByString:@""];
//        gray_img= descriptors;
//        NSData *ddd=[NSData dataWithBytes:descriptors.data length:descriptors.elemSize()*descriptors.total()];
        //        NSString *desc= << descriptors << std::endl;
//        NSString *str=[[NSString alloc] initWithData:ddd encoding:NSUTF8StringEncoding];
//        std::cout << descriptors << std::endl;
//        NSLog(str);1
        
//        NSLog(@"ccccc, this is a native function called from PhoneGap/Cordova!");
        //    cv::String abc=detector.name();
        //    detector.paramHelp("abc");
        //    NSString *bb=abc.;
        //    NSLog(@"ccccc, this is a native function called from PhoneGap/Cordova!");
        
        //    detector.compute(src_img, keypoints, descriptors);
        //    detector.detect(src_img, objectKeypoints);
        
        //        //グレースケールに変換する
        //        cv::Mat gray_img;
        //        cv::cvtColor(src_img, gray_img, CV_RGB2GRAY);
        //    printf; cv::cvtColor::CV_RGB2GRAY;
        //Mat型をUIImage型に変換して、viewのbackgroundに設定する
        //    newImage = MatToUIImage(gray_img);
//        UIImage *image2 = [UIImage imageWithMat:gray_img andImageOrientation:0];
        
        cv::Mat cvMat=gray_img;
        
        
        
        NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
        NSMutableString * str2 = [NSMutableString string];

        /*
         */
//        uchar
        unsigned char *buffer =descriptors.data;
//        uchar arr2[];
//        NSString *myString = [[NSString alloc] initWithData:descriptors.data encoding:NSUTF8StringEncoding];
        
                NSString *abc=@"";
//        NSString myIntegers[descriptors.rows*descriptors.cols];
        int i[] = {1,2,3,4,5,6,7};
        
        int len = sizeof(i) / sizeof(int);
        
        NSMutableString * str = [NSMutableString string];
        for (int j = 0; j<len; j++) {
            [str appendFormat:@"%i ", i[j]];
        }
        NSInteger sum=0;
         //        for (int j = 0; j<len; j++) {
        //        }
        NSMutableArray *stringArray2 = [[NSMutableArray alloc] init];
                    for(int j = 0; j < descriptors.rows; j++)
                    {
                        NSMutableArray *stringArray = [[NSMutableArray alloc] init];
                        for(int i=0; i< descriptors.cols; i++){
                            NSInteger result = [[NSNumber numberWithUnsignedChar: buffer[j*descriptors.cols+i]] intValue];
                            [stringArray addObject: [NSString stringWithFormat:@"%d",result]];
                        }
                        NSString *joinedString =[[stringArray copy] componentsJoinedByString:@","];
                        [stringArray2 addObject: joinedString];
                        
//                        abc = [NSString stringWithFormat:@"%@ %d",abc,(int)result];
//                        sum += result;
//                        [str2 appendFormat:@"%i ", result];
                        //                        myIntegers[j] = (NSString)result;
//                        [str appendFormat:@"%i ", 5];

                    }
        NSString *joinedString2 =[[stringArray2 copy] componentsJoinedByString:@"],["];
        str2 = [NSString stringWithFormat:@"[[%@]]",joinedString2];

//        NSLog(@"%@",str2);
        
        colorSpace;
        
        if (cvMat.elemSize() == 1) {
            colorSpace = CGColorSpaceCreateDeviceGray();
        } else {
            colorSpace = CGColorSpaceCreateDeviceRGB();
        }
         
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
         
        // Creating CGImage from cv::Mat
        CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                            cvMat.rows,                                 //height
                                            8,                                          //bits per component
                                            8 * cvMat.elemSize(),                       //bits per pixel
                                            cvMat.step[0],                            //bytesPerRow
                                            colorSpace,                                 //colorspace
                                            kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                            provider,                                   //CGDataProviderRef
                                            NULL,                                       //decode
                                            false,                                      //should interpolate
                                            kCGRenderingIntentDefault                   //intent
                                            );
        
        
        // Getting UIImage from CGImage
        UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
        CGImageRelease(imageRef);
        CGDataProviderRelease(provider);
        CGColorSpaceRelease(colorSpace);

        
        
        
//        finalImage = [CanvasCamera resizeImage:finalImage toSize:CGSizeMake(width/2, height/2)];
        
        
        // Convert to Base64 data
//        NSData *base64Data = [data base64EncodedDataWithOptions:0];
//        NSString *strData = [NSString stringWithUTF8String:(const char *)[base64Data bytes]];
//        
//        [dicRet setObject:strData forKey:@"imageURI"];

        
//        NSData *imageData = UIImageJPEGRepresentation(image2, 0.01);
        NSData *imageData = UIImageJPEGRepresentation(finalImage, 1.0);
#if 0
        //NSString *encodedString = [imageData base64Encoding];
        NSString *encodedString = [imageData base64EncodedStringWithOptions:0];
        
        NSString *javascript = @"CanvasCamera.capture('data:image/jpeg;base64,";
        
        javascript = [NSString stringWithFormat:@"%@%@%@", javascript, encodedString, @"','abc');"];
        
        javascript = [NSString stringWithFormat:@"%@%@%@%@", javascript, @"CanvasCamera.detect('",str2,@"');"];
        
        [self.webView performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:) withObject:javascript waitUntilDone:YES];
#else
        dispatch_async(dispatch_get_main_queue(), ^{
            @autoreleasepool {
                
                // Get a file path to save the JPEG
                static int i = 0;
                i++;
                
                NSString *imagePath = [CanvasCamera getFilePath:[NSString stringWithFormat:@"uuid%d", i] ext:@"jpg"];
                
                if (i > 10)
                {
                    NSString *prevPath = [CanvasCamera getFilePath:[NSString stringWithFormat:@"uuid%d", i-10] ext:@"jpg"];
                    NSError *error = nil;
                    [[NSFileManager defaultManager] removeItemAtPath:prevPath error:&error];
                }
                
                // Write the data to the file
                [imageData writeToFile:imagePath atomically:YES];
                
                imagePath = [NSString stringWithFormat:@"file://%@", imagePath];
                
                //[retValues setObject:strUrl forKey:kDataKey];
                //[retValues setObject:imagePath forKey:kDataKey];
                
                NSString *javascript = [NSString stringWithFormat:@"%@%@%@", @"CanvasCamera.capture('", imagePath, @"',555);"];
                javascript = [NSString stringWithFormat:@"%@%@%@%@", javascript, @"CanvasCamera.detect('",str2,@"');"];
                
                
                
                
                NSString *encodedString = [imageData base64EncodedStringWithOptions:0];
                
                NSString *str3 = @"data:image/jpeg;base64,";
                
                str3 = [NSString stringWithFormat:@"%@%@%@", str3, encodedString, @""];
                
                
                [self.webView performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:) withObject:javascript waitUntilDone:YES];
                
                
                
                
                javascript = [NSString stringWithFormat:@"%@%@%@%@", javascript, @"CanvasCamera.base64('",str3,@"');"];
                [self.webView stringByEvaluatingJavaScriptFromString:javascript];
            }
        });
#endif
        
        CGImageRelease(newImage);
        CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    }
}

#pragma mark - Utilities

-(UIImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}
- (cv::Mat)cvMatGrayFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC1); // 8 bits per component, 1 channels
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}


// utility routing used during image capture to set up capture orientation
- (AVCaptureVideoOrientation)avOrientationForDeviceOrientation:(UIDeviceOrientation)deviceOrientation
{
    AVCaptureVideoOrientation result = (AVCaptureVideoOrientation)deviceOrientation;
    result=AVCaptureVideoOrientationPortrait;
    //	if ( deviceOrientation == UIDeviceOrientationLandscapeLeft )
    //		result = AVCaptureVideoOrientationLandscapeRight;
    //	else if ( deviceOrientation == UIDeviceOrientationLandscapeRight )
    //		result = AVCaptureVideoOrientationLandscapeLeft;
    return result;
}


// Find a camera with the specified AVCaptureDevicePosition, returning nil if one is not found
- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == position)
            return device;
    }
    return nil;
}

// utility routine to create a new image with specified size(_width, _height)
// and return the new composited image which can be saved to the camera roll
- (CGImageRef)createResizedCGImage:(CGImageRef)srcImage withSize:(CGSize)size
{
    CGImageRef returnImage = NULL;
    CGRect newImageRect = CGRectMake(0, 0, size.width, size.height);
    CGContextRef bitmapContext = (CGContextRef)CreateCGBitmapContextForSize(size);
    CGContextClearRect(bitmapContext, newImageRect);
    CGContextDrawImage(bitmapContext, newImageRect, srcImage);
    
    returnImage = CGBitmapContextCreateImage(bitmapContext);
    CGContextRelease (bitmapContext);
    
    return returnImage;
}


+ (NSString *)GetUUID
{
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return (__bridge NSString *)string;
}

+ (NSString *)getFilePath:(NSString *)uuidString ext:(NSString *)ext
{
    NSString *documentsDirectory = [CanvasCamera getAppPath];
    NSString* filename = [NSString stringWithFormat:@"%@.%@", uuidString, ext];
    NSString* imagePath = [documentsDirectory stringByAppendingPathComponent:filename];
    return imagePath;
}

+ (NSString *)getAppPath
{
    // Get a file path to save the JPEG
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documentsDirectory = [paths objectAtIndex:0];
    NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:@"/tmp"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:dataPath])
    {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:dataPath withIntermediateDirectories:NO attributes:nil error:&error]; //Create folder
        if (error) {
            NSLog(@"error occurred in create tmp folder : %@", [error localizedDescription]);
        }
    }
    return dataPath;
}

/**
 * parse options parameter and set it to local variables
 *
 */

- (void)getOptions: (NSDictionary *)jsonData
{
    if (![jsonData isKindOfClass:[NSDictionary class]])
        return;
    
    // get parameters from argument.
    
    // quaility
    NSString *obj = [jsonData objectForKey:kQualityKey];
    if (obj != nil)
        _quality = [obj intValue];
    
    // destination type
    obj = [jsonData objectForKey:kDestinationTypeKey];
    if (obj != nil)
    {
        int destinationType = [obj intValue];
        NSLog(@"destinationType = %d", destinationType);
        _destType = (DestinationType)destinationType;
    }
    
    // encoding type
    obj = [jsonData objectForKey:kEncodingTypeKey];
    if (obj != nil)
    {
        int encodingType = [obj intValue];
        _encodeType = (EncodingType)encodingType;
    }
    
    // width
    obj = [jsonData objectForKey:kWidthKey];
    if (obj != nil)
    {
        _width = [obj intValue];
    }
    
    // height
    obj = [jsonData objectForKey:kHeightKey];
    if (obj != nil)
    {
        _height = [obj intValue];
    }
    
    // saveToPhotoAlbum
    obj = [jsonData objectForKey:kSaveToPhotoAlbumKey];
    if (obj != nil)
    {
        _saveToPhotoAlbum = [obj boolValue];
    }
    
    // correctOrientation
    obj = [jsonData objectForKey:kCorrectOrientationKey];
    if (obj != nil)
    {
        _correctOrientation = [obj boolValue];
    }
}


+ (NSString *)date2str:(NSDate *)convertDate withFormat:(NSString *)formatString
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:formatString];
    
    return [dateFormatter stringFromDate:convertDate];
}



static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};

// utility routine used after taking a still image to write the resulting image to the camera roll
- (BOOL)writeCGImageToCameraRoll:(CGImageRef)cgImage withMetadata:(NSDictionary *)metadata withQuality:(CGFloat)quality withEncodingType:(EncodingType)encodingType
{
    CFMutableDataRef destinationData = CFDataCreateMutable(kCFAllocatorDefault, 0);
    CGImageDestinationRef destination = nil;
    if (encodingType == EncodingTypeJPEG)
        destination = CGImageDestinationCreateWithData(destinationData,
                                                       kUTTypeJPEG,
                                                       1,
                                                       NULL);
    else
        destination = CGImageDestinationCreateWithData(destinationData,
                                                       kUTTypePNG,
                                                       1,
                                                       NULL);
    BOOL success = (destination != NULL);
    if (!success)
    {
        if (destinationData)
            CFRelease(destinationData);
        return success;
    }
    
    const float JPEGCompQuality = quality; // JPEGHigherQuality (0 ~ 1)
    CFMutableDictionaryRef optionsDict = NULL;
    CFNumberRef qualityNum = NULL;
    
    qualityNum = CFNumberCreate(0, kCFNumberFloatType, &JPEGCompQuality);
    if ( qualityNum ) {
        optionsDict = CFDictionaryCreateMutable(0, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        if ( optionsDict )
            CFDictionarySetValue(optionsDict, kCGImageDestinationLossyCompressionQuality, qualityNum);
        CFRelease( qualityNum );
    }
    
    CGImageDestinationAddImage( destination, cgImage, optionsDict );
    success = CGImageDestinationFinalize( destination );
    
    if ( optionsDict )
        CFRelease(optionsDict);
    
    if (!success)
    {
        if (destination)
            CFRelease(destination);
        if (destinationData)
            CFRelease(destinationData);
        return success;
    }
    
    CFRetain(destinationData);
    ALAssetsLibrary *library = [ALAssetsLibrary new];
    [library writeImageDataToSavedPhotosAlbum:(__bridge id)destinationData metadata:metadata completionBlock:^(NSURL *assetURL, NSError *error) {
        if (destinationData)
            CFRelease(destinationData);
    }];
    //[library release];
    
    if (destination)
        CFRelease(destination);
    if (destinationData)
        CFRelease(destinationData);
    return success;
}

// utility routine used after taking a still image to write the resulting image to the camera roll
- (BOOL)writeCGImageToPath:(CGImageRef)cgImage withMetadata:(NSDictionary *)metadata withQuality:(CGFloat)quality withEncodingType:(EncodingType)encodingType toPath:(NSString *)path
{
    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
    CGImageDestinationRef destination = nil;
    if (encodingType == EncodingTypeJPEG)
        destination = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, NULL);
    else
        destination = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, NULL);
    
    const float JPEGCompQuality = quality; // JPEGHigherQuality (0 ~ 1)
    CFMutableDictionaryRef optionsDict = NULL;
    CFNumberRef qualityNum = NULL;
    
    qualityNum = CFNumberCreate(0, kCFNumberFloatType, &JPEGCompQuality);
    if ( qualityNum ) {
        optionsDict = CFDictionaryCreateMutable(0, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        if ( optionsDict )
            CFDictionarySetValue(optionsDict, kCGImageDestinationLossyCompressionQuality, qualityNum);
        CFRelease( qualityNum );
    }
    
    CGImageDestinationAddImage(destination, cgImage, optionsDict);
    
    BOOL success = CGImageDestinationFinalize(destination);
    if (!success) {
        NSLog(@"Failed to write image to %@", path);
    }
    
    
    if ( optionsDict )
        CFRelease(optionsDict);
    
    CFRelease(destination);
    
    return success;
}

- (BOOL)writeData:(NSData *)data toPath:(NSString *)path
{
    BOOL success = [data writeToFile:path atomically:YES];
    return success;
}

- (BOOL)writeJPGToCameraRoll:(NSData *)jpegData withAttachments:(CFDictionaryRef)attachments
{
    if (attachments)
        CFRetain(attachments);
    
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library writeImageDataToSavedPhotosAlbum:jpegData metadata:(__bridge id)attachments completionBlock:^(NSURL *assetURL, NSError *error) {
        if (attachments)
            CFRelease(attachments);
        if (error) {
            NSLog(@"Failed to save image to camera roll : %@", [error localizedDescription]);
        }
        else
        {
            //
        }
    }];
    
    return YES;
}

// utility used by newSquareOverlayedImageForFeatures for
static CGContextRef CreateCGBitmapContextForSize(CGSize size);
static CGContextRef CreateCGBitmapContextForSize(CGSize size)
{
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    int             bitmapBytesPerRow;
    
    bitmapBytesPerRow = (size.width * 4);
    
    colorSpace = CGColorSpaceCreateDeviceRGB();
    context = CGBitmapContextCreate (NULL,
                                     size.width,
                                     size.height,
                                     8,      // bits per component
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     kCGImageAlphaPremultipliedLast);
    CGContextSetAllowsAntialiasing(context, NO);
    CGColorSpaceRelease( colorSpace );
    return context;
}


static void ReleaseCVPixelBuffer(void *pixel, const void *data, size_t size);
static void ReleaseCVPixelBuffer(void *pixel, const void *data, size_t size)
{
    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)pixel;
    CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
    CVPixelBufferRelease( pixelBuffer );
}

// create a CGImage with provided pixel buffer, pixel buffer must be uncompressed kCVPixelFormatType_32ARGB or kCVPixelFormatType_32BGRA
static OSStatus CreateCGImageFromCVPixelBuffer(CVPixelBufferRef pixelBuffer, CGImageRef *imageOut);
static OSStatus CreateCGImageFromCVPixelBuffer(CVPixelBufferRef pixelBuffer, CGImageRef *imageOut)
{
    OSStatus err = noErr;
    OSType sourcePixelFormat;
    size_t width, height, sourceRowBytes;
    void *sourceBaseAddr = NULL;
    CGBitmapInfo bitmapInfo;
    CGColorSpaceRef colorspace = NULL;
    CGDataProviderRef provider = NULL;
    CGImageRef image = NULL;
    
    sourcePixelFormat = CVPixelBufferGetPixelFormatType( pixelBuffer );
    if ( kCVPixelFormatType_32ARGB == sourcePixelFormat )
        bitmapInfo = kCGBitmapByteOrder32Big | kCGImageAlphaNoneSkipFirst;
    else if ( kCVPixelFormatType_32BGRA == sourcePixelFormat )
        bitmapInfo = kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst;
    else
        return -95014; // only uncompressed pixel formats
    
    sourceRowBytes = CVPixelBufferGetBytesPerRow( pixelBuffer );
    width = CVPixelBufferGetWidth( pixelBuffer );
    height = CVPixelBufferGetHeight( pixelBuffer );
    
    CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
    sourceBaseAddr = CVPixelBufferGetBaseAddress( pixelBuffer );
    
    colorspace = CGColorSpaceCreateDeviceRGB();
    
    CVPixelBufferRetain( pixelBuffer );
    provider = CGDataProviderCreateWithData( (void *)pixelBuffer, sourceBaseAddr, sourceRowBytes * height, ReleaseCVPixelBuffer);
    image = CGImageCreate(width, height, 8, 32, sourceRowBytes, colorspace, bitmapInfo, provider, NULL, true, kCGRenderingIntentDefault);
    
bail:
    if ( err && image ) {
        CGImageRelease( image );
        image = NULL;
    }
    if ( provider ) CGDataProviderRelease( provider );
    if ( colorspace ) CGColorSpaceRelease( colorspace );
    *imageOut = image;
    return err;
}

@end
