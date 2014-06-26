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
#import "MultichannelCindeGLView.h"
#import "FPPopoverController.h"
#import "BBChannelSelectionTableViewController.h"

@interface ViewAndRecordViewController : CCGLTouchViewController <MultichannelGLViewDelegate, FPPopoverControllerDelegate, BBSelectionTableDelegateProtocol>{
    MultichannelCindeGLView *glView;
     FPPopoverController * popover;
}

- (void)setGLView:(CCGLTouchView *)view;


@property (retain, nonatomic) IBOutlet UISlider *slider;
@property (retain, nonatomic) IBOutlet UIButton *recordButton;
@property (retain, nonatomic) IBOutlet UIButton *stimulateButton;
@property (retain, nonatomic) IBOutlet UIButton *stimulatePreferenceButton;
@property (retain, nonatomic) IBOutlet UIButton *stopButton;
@property (retain, nonatomic) IBOutlet UIButton *btButton;

- (IBAction)stimulateButtonPressed:(id)sender;
- (IBAction)stimulatePrefButtonPressed:(id)sender;
- (IBAction)stopRecording:(id)sender;
- (IBAction)startRecording:(id)sender;
- (IBAction)btButtonPressed:(id)sender;

//BT popover delegate function
- (void)rowSelected:(NSInteger) rowIndex;
-(NSMutableArray *) getAllRows;

@end
