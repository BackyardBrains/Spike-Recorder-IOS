//
//  FFTViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/16/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "CCGLTouchViewController.h"
#import "DynamicFFTCinderGLView.h"
#import "BBAudioManager.h"
#import "FPPopoverController.h"
#import "BBChannelSelectionTableViewController.h"

@interface FFTViewController : CCGLTouchViewController <FPPopoverControllerDelegate,BBSelectionTableDelegateProtocol, DynamicFFTProtocolDelegate>
{
    DynamicFFTCinderGLView *glView;
    FPPopoverController * popover;
}
@property (retain, nonatomic) IBOutlet UIButton *channelBtn;
@property (retain, nonatomic) IBOutlet UIButton *backButton;
- (IBAction)channelBtnClick:(id)sender;
- (IBAction)backButtonPressed:(id)sender;


//DynamicFFTProtocolDelegate functions
-(void) glViewTouched;

@end
