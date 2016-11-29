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
#import "BBAudioManager.h"
#import "BBFile.h"

#import "MultichannelCindeGLView.h"
#import "FPPopoverController.h"
#import "BBChannelSelectionTableViewController.h"
#import "RTSpikeSortingButton.h"
#import "BufferStateIndicator.h"
#import "RTCancelButton.h"
//#import <CoreBluetooth/CoreBluetooth.h>

@interface ViewAndRecordViewController : CCGLTouchViewController <MultichannelGLViewDelegate, FPPopoverControllerDelegate, BBSelectionTableDelegateProtocol>{
    
    FPPopoverController * channelPopover;
    FPPopoverController * devicesPopover;
}

- (void)setGLView:(MultichannelCindeGLView *)view;


@property (retain, nonatomic) IBOutlet UISlider *slider;
@property (retain, nonatomic) IBOutlet UIButton *recordButton;
@property (retain, nonatomic) IBOutlet UIButton *stopButton;
@property (retain, nonatomic) IBOutlet UIButton *btButton;
@property (retain, nonatomic) IBOutlet BufferStateIndicator *bufferStateIndicator;

@property (retain, nonatomic) IBOutlet RTSpikeSortingButton *rtSpikeViewButton;
@property (retain, nonatomic) IBOutlet RTCancelButton *cancelRTViewButton;

@property (retain, nonatomic) MultichannelCindeGLView *glView;

- (IBAction)stopRecording:(id)sender;
- (IBAction)startRecording:(id)sender;
- (IBAction)btButtonPressed:(id)sender;

//BT popover delegate function
- (void)rowSelected:(NSInteger) rowIndex;
-(NSMutableArray *) getAllRows;
-(void) selectChannel:(int) selectedChannel;
-(void) updateBTBufferIndicator;

@end
