//
//  SpikesAnalysisViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/10/14.
//  Copyright (c) Backyard Brains. All rights reserved.
//

#import "CCGLTouchViewController.h"
#import "SpikesCinderView.h"
#import "BBAnalysisManager.h"
#import "BBFile.h"
#import "FPPopoverController.h"
#import "BBChannelSelectionTableViewController.h"
#import "BYBHandleButton.h"

@protocol BBSpikeSortingViewControllerDelegate;

@interface SpikesAnalysisViewController : CCGLTouchViewController <FPPopoverControllerDelegate,BBSelectionTableDelegateProtocol> {
    SpikesCinderView *glView;
    FPPopoverController * popover;
}

@property (retain, nonatomic) IBOutlet BYBHandleButton *nextBtn;
@property (retain, nonatomic) IBOutlet UISlider *timeSlider;
@property (retain, nonatomic) IBOutlet UIButton *addTrainBtn;
@property (retain, nonatomic) IBOutlet UIButton *removeTrainButton;
@property (retain, nonatomic) IBOutlet UIButton *channelBtn;

//config init view
@property (retain, nonatomic) BBFile *bbfile;
@property (assign, nonatomic) id <BBSpikeSortingViewControllerDelegate> masterDelegate;


//GL stuff
- (void)setGLView:(CCGLTouchView *)view;

//View handlers
- (IBAction)timeValueChanged:(id)sender;
- (IBAction)channelClick:(id)sender;
- (IBAction)backBtnClick:(id)sender;
- (IBAction)addTrainClick:(id)sender;
- (IBAction)removeTrainClick:(id)sender;

//BBSelectionTableDelegateProtocol functions
- (void)rowSelected:(NSInteger) rowIndex;
- (NSMutableArray *) getAllRows;
@end

@protocol BBSpikeSortingViewControllerDelegate
@required
- (void) spikesSortingFinished;
@end

