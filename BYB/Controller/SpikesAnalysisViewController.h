//
//  SpikesAnalysisViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/10/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "CCGLTouchViewController.h"
#import "SpikesCinderView.h"
#import "BBAnalysisManager.h"
#import "BBFile.h"
#import "FPPopoverController.h"
#import "BBChannelSelectionTableViewController.h"
#import "BYBHandleButton.h"

@protocol BBSpikeSortingViewControllerDelegate
@required
- (void) spikesSortingFinished;
@end

@interface SpikesAnalysisViewController : CCGLTouchViewController <FPPopoverControllerDelegate,BBSelectionTableDelegateProtocol> {
    SpikesCinderView *glView;
    FPPopoverController * popover;
}
@property (retain, nonatomic) IBOutlet BYBHandleButton *nextBtn;

- (IBAction)backBtnClick:(id)sender;
@property (retain, nonatomic) IBOutlet UISlider *timeSlider;
@property (retain, nonatomic) BBFile *bbfile;
@property (assign, nonatomic) id <BBSpikeSortingViewControllerDelegate> masterDelegate;



- (void)setGLView:(CCGLTouchView *)view;
- (IBAction)timeValueChanged:(id)sender;
@property (retain, nonatomic) IBOutlet UIButton *addTrainBtn;
@property (retain, nonatomic) IBOutlet UIButton *removeTrainButton;
@property (retain, nonatomic) IBOutlet UIButton *channelBtn;


- (IBAction)channelClick:(id)sender;

- (IBAction)addTrainClick:(id)sender;
- (IBAction)removeTrainClick:(id)sender;

- (void)rowSelected:(NSInteger) rowIndex;
-(NSMutableArray *) getAllRows;
@end


