//
//  PlaybackViewController.h
//  New Focus
//
//  Created by Alex Wiltschko on 7/9/12.
//  Copyright (c) 2012 Datta Lab, Harvard University. All rights reserved.
//

#import "CCGLTouchViewController.h"
#import "MyCinderGLView.h"
#import "BBAudioManager.h"
#import "BBFile.h"
#import "MultichannelCindeGLView.h"

@interface PlaybackViewController : CCGLTouchViewController <MultichannelGLViewDelegate>
{
    MultichannelCindeGLView *glView;
}

- (void)setGLView:(CCGLTouchView *)view;

@property (retain, nonatomic) BBFile *bbfile;

@property (retain, nonatomic) IBOutlet UIButton *playPauseButton;
@property (retain, nonatomic) IBOutlet UISlider *timeSlider;


- (IBAction)sliderValueChanged:(id)sender;
- (IBAction)playPauseButtonPressed:(id)sender;

//MultichannelGLViewDelegate protocol functions
- (float) fetchDataToDisplay:(float *)data numFrames:(UInt32)numFrames whichChannel:(UInt32)whichChannel;
- (void) selectChannel:(int) selectedChannel;
-(BOOL) shouldEnableSelection;
-(void) updateSelection:(float) newSelectionTime;
-(float) selectionStartTime;
-(float) selectionEndTime;
-(void) endSelection;
-(BOOL) selecting;
-(float) rmsOfSelection;
@end
