//
//  RecordingOverlay.m
//  BYB2
//
//  Created by Alex Wiltschko on 8/7/12.
//  Copyright (c) 2012 Datta Lab, Harvard University. All rights reserved.
//

#import "RecordingOverlay.h"

@implementation RecordingOverlay

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.backgroundColor = [UIColor clearColor];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(rotate)
                                                     name:@"UIDeviceOrientationDidChangeNotification"
                                                   object:nil];

    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    
    float w = rect.size.width;
    float h = rect.size.height;
    
    //// General Declarations
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //// Color Declarations
    UIColor* gradientColor = [UIColor colorWithRed: 1 green: 0.15 blue: 0 alpha: 1];
    UIColor* gradientColor2 = [UIColor colorWithRed: 1 green: 0.49 blue: 0.47 alpha: 1];
    UIColor* gradientColor3 = [UIColor colorWithRed: 1 green: 0.49 blue: 0.47 alpha: 1];
    
    //// Gradient Declarations
    NSArray* gradientColors = [NSArray arrayWithObjects:
                               (id)[UIColor redColor].CGColor,
                               (id)[UIColor colorWithRed: 1 green: 0.3 blue: 0.26 alpha: 1].CGColor,
                               (id)gradientColor2.CGColor,
                               (id)[UIColor colorWithRed: 1 green: 0.3 blue: 0.26 alpha: 1].CGColor,
                               (id)gradientColor.CGColor,
                               (id)gradientColor3.CGColor, nil];
    CGFloat gradientLocations[] = {0, 0.26, 0.53, 0.53, 0.56, 1};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (CFArrayRef)gradientColors, gradientLocations);
    
    //// Abstracted Graphic Attributes
    NSString* recordingTextContent = @"Recording (tap to end)";
    
    // UNCOMMENT THIS WHEN THINGS ARE FOR REALSIES
    float currentFileTime = [[BBAudioManager bbAudioManager] fileDuration];
    
    int minutes = (int)floor(currentFileTime / 60.0f);
    int seconds = (int)(currentFileTime - minutes*60);
    NSString* timeTextContent = [NSString stringWithFormat:@"%d:%02d", minutes, seconds];
    
    
    //// Panel Drawing
    UIBezierPath* panelPath = [UIBezierPath bezierPath];
    [panelPath moveToPoint: CGPointMake(.9484375*w, .184375*h)];
    [panelPath addLineToPoint: CGPointMake(.0546875*w, .184375*h)];
    [panelPath addCurveToPoint: CGPointMake(.0484375*w, .188541667*h) controlPoint1: CGPointMake(.05125*w, .184375*h) controlPoint2: CGPointMake(.0484375*w, .18625*h)];
    [panelPath addLineToPoint: CGPointMake(.0484375*w, .857291667*h)];
    [panelPath addCurveToPoint: CGPointMake(.0546875*w, .861458333*h) controlPoint1: CGPointMake(.0484375*w, .859583333*h) controlPoint2: CGPointMake(.05125*w, .861458333*h)];
    [panelPath addLineToPoint: CGPointMake(.9484375*w, .861458333*h)];
    [panelPath addCurveToPoint: CGPointMake(.9546875*w, .857291667*h) controlPoint1: CGPointMake(.951875*w, .861458333*h) controlPoint2: CGPointMake(.9546875*w, .859583333*h)];
    [panelPath addLineToPoint: CGPointMake(.9546875*w, .188541667*h)];
    [panelPath addCurveToPoint: CGPointMake(.9484375*w, .184375*h) controlPoint1: CGPointMake(.9546875*w, .18625*h) controlPoint2: CGPointMake(.951875*w, .184375*h)];
    [panelPath closePath];
    [panelPath moveToPoint: CGPointMake(1.0*w, 1.0*h)];
    [panelPath addLineToPoint: CGPointMake(0.0*w, 1.0*h)];
    [panelPath addLineToPoint: CGPointMake(0.0*w, 0.0*h)];
    [panelPath addLineToPoint: CGPointMake(1.0*w, 0.0*h)];
    [panelPath addLineToPoint: CGPointMake(1.0*w, 1.0*h)];
    [panelPath closePath];
    CGContextSaveGState(context);
    [panelPath addClip];
    CGContextDrawLinearGradient(context, gradient, CGPointMake(-39, 41), CGPointMake(360, 440), 0);
    CGContextRestoreGState(context);
    
    
    
    //// recording text Drawing
    CGRect recordingTextRect = CGRectMake(.0875*w, .041666667*h, .81875*w, .066666667*h);
    [[UIColor whiteColor] setFill];
    [recordingTextContent drawInRect: recordingTextRect withFont: [UIFont fontWithName: @"Helvetica" size: 18] lineBreakMode: UILineBreakModeWordWrap alignment: UITextAlignmentCenter];
    
    
    //// time text Drawing
    float x,y;
    if (UIDeviceOrientationIsPortrait([[UIDevice currentDevice] orientation])) {
        x = 30.0;
        y = 43.0;
    }
    else {
        x = 200.0;
        y = 12.0;
    }

    CGRect timeTextRect = CGRectMake(x, y, .81875*w, .095833333);
    [[UIColor whiteColor] setFill];
    [timeTextContent drawInRect: timeTextRect withFont: [UIFont fontWithName: @"Helvetica" size: 30] lineBreakMode: UILineBreakModeWordWrap alignment: UITextAlignmentCenter];
    
    //// Cleanup
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

- (void)rotate
{
	
	UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
	if (orientation == UIDeviceOrientationFaceUp || orientation == UIDeviceOrientationFaceDown)
		return;
    
	CGAffineTransform transform;
	
    
    
    if (UIDeviceOrientationIsLandscape(orientation)) {
        switch (orientation) {
            case UIDeviceOrientationLandscapeLeft:
                transform = CGAffineTransformRotate(CGAffineTransformIdentity, M_PI / 2.0);
                break;
            case UIDeviceOrientationLandscapeRight:
                transform = CGAffineTransformRotate(CGAffineTransformIdentity, -M_PI / 2.0);
                break;
            default:
                transform = CGAffineTransformIdentity;
        }
    }
	
    else {
        switch (orientation) {
            case UIDeviceOrientationPortrait:
                transform = CGAffineTransformIdentity;
                break;
                
            case UIDeviceOrientationPortraitUpsideDown:
                transform = CGAffineTransformRotate(CGAffineTransformIdentity, M_PI);
                break;
            default:
                transform = CGAffineTransformIdentity;
        }
    }
	
	self.transform = transform;
    
    if (UIDeviceOrientationIsPortrait(orientation)) {
        self.frame = [[UIScreen mainScreen] bounds];
    }
    else if (UIDeviceOrientationIsLandscape(orientation)) {
        CGRect newFrame = [[UIScreen mainScreen] bounds];
        newFrame.origin.x = 0;
        newFrame.origin.y = 0;
        self.frame = newFrame;
        
    }
	
	
}



@end
