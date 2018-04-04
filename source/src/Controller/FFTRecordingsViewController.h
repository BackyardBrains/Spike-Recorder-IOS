//
//  FFTRecordingsViewController.h
//  Spike Recorder
//
//  Created by Stanislav Mircic on 2/22/18.
//  Copyright © 2018 BackyardBrains. All rights reserved.
//

#ifndef FFTRecordingsViewController_h
#define FFTRecordingsViewController_h

#import "CCGLTouchViewController.h"
#import "DynamicFFTCinderGLView.h"
#import "BBAudioManager.h"
#import "FPPopoverController.h"
#import "BBChannelSelectionTableViewController.h"

@interface FFTRecordingsViewController : CCGLTouchViewController <FPPopoverControllerDelegate,BBSelectionTableDelegateProtocol, DynamicFFTProtocolDelegate>
{
    DynamicFFTCinderGLView *glView;
    FPPopoverController * popover;
}
@property (retain, nonatomic) IBOutlet UIButton *channelBtn;
@property (retain, nonatomic) IBOutlet UIButton *backButton;
@property (retain, nonatomic) IBOutlet UISlider *timeSlider;
@property (retain, nonatomic) IBOutlet UIButton *playPauseButton;
@property (retain, nonatomic) BBFile *bbfile;

// UI handlers
- (IBAction)channelBtnClick:(id)sender;
- (IBAction)backButtonPressed:(id)sender;
- (IBAction)sliderValueChanged:(id)sender;
- (IBAction)playPauseButtonPressed:(id)sender;

//DynamicFFTProtocolDelegate functions
-(void) glViewTouched;
-(bool) areWeInFileMode;


@end

#endif /* FFTRecordingsViewController_h */
