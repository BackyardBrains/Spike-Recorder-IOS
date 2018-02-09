//
//  PlaybackViewController.h
//  Copyright (c) 2012 Backyard Brains. All rights reserved.
//

#import "CCGLTouchViewController.h"
#import "BBAudioManager.h"
#import "BBFile.h"
#import "MultichannelCindeGLView.h"

@interface PlaybackViewController : CCGLTouchViewController <MultichannelGLViewDelegate>
{
}

@property (retain, nonatomic) IBOutlet UIButton *playPauseButton;
@property (retain, nonatomic) IBOutlet UISlider *timeSlider;

// view handlers
- (IBAction)backBtnClick:(id)sender;
- (IBAction)sliderValueChanged:(id)sender;
- (IBAction)playPauseButtonPressed:(id)sender;

//GL view stuff
- (void)setGLView:(CCGLTouchView *)view;
@property (retain, nonatomic) MultichannelCindeGLView *glView;

//config init view
@property (nonatomic) BOOL showNavigationBar;
@property (retain, nonatomic) BBFile *bbfile;

//MultichannelGLViewDelegate protocol functions
- (float) fetchDataToDisplay:(float *)data numFrames:(UInt32)numFrames whichChannel:(UInt32)whichChannel;
- (void)  selectChannel:(int) selectedChannel;
- (BOOL)  shouldEnableSelection;
- (void)  updateSelection:(float) newSelectionTime timeSpan:(float) timeSpan;
- (float) selectionStartTime;
- (float) selectionEndTime;
- (void)  endSelection;
- (BOOL)  selecting;
- (float) rmsOfSelection;
@end
