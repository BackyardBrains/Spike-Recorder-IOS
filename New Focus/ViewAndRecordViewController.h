//
//  MyViewController.h
//  CCGLTouchBasic example
//
//  Created by Matthieu Savary on 09/09/11.
//  Copyright (c) 2011 SMALLAB.ORG. All rights reserved.
//
//  More info on the CCGLTouch project >> http://www.smallab.org/code/ccgl-touch/
//  License & disclaimer >> see license.txt file included in the distribution package
//

#import "CCGLTouchViewController.h"
#import "MyCinderGLView.h"
#import "BBAudioManager.h"
#import "BBFile.h"
#import "RecordingOverlayController.h"

@interface ViewAndRecordViewController : CCGLTouchViewController {
    MyCinderGLView *glView;
    
}

- (void)setGLView:(CCGLTouchView *)view;


@property (retain, nonatomic) IBOutlet UISlider *slider;
@property (retain, nonatomic) IBOutlet UIButton *recordButton;
@property (retain, nonatomic) IBOutlet UIButton *stimulateButton;
@property (retain, nonatomic) IBOutlet UIButton *stimulatePreferenceButton;
@property (retain, nonatomic) IBOutlet UIButton *stopButton;

- (IBAction)listenToCubeSizeSlider:(id)sender;
- (IBAction)recordButtonPressed:(id)sender;
- (IBAction)stimulateButtonPressed:(id)sender;
- (IBAction)stimulatePrefButtonPressed:(id)sender;
- (IBAction)stopRecording:(id)sender;
- (IBAction)startRecording:(id)sender;


@end
