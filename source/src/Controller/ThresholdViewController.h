//
// BackyardBrains
//
// ThresholdViewController.h
//
// Threshold and average signal based on threshold level
// Shows BPM for heart rate
//

#import "CCGLTouchViewController.h"
#import "BBAudioManager.h"
#import "MultichannelCindeGLView.h"

@interface ThresholdViewController : CCGLTouchViewController <MultichannelGLViewDelegate>
{
}

@property (retain, nonatomic) IBOutlet UILabel *triggerHistoryLabel;
@property (retain, nonatomic) IBOutlet UIImageView *activeHeartImg;

//view handlers
- (IBAction)updateNumTriggersInThresholdHistory:(id)sender;

//GL view stuff
@property (retain, nonatomic) MultichannelCindeGLView *glView;
- (void) setGLView:(MultichannelCindeGLView *)view;

//MultichannelGLViewDelegate stuff
-(float) fetchDataToDisplay:(float *)data numFrames:(UInt32)numFrames whichChannel:(UInt32)whichChannel;
-(void)  selectChannel:(int) selectedChannel;
-(BOOL)  shouldEnableSelection;
-(void)  updateSelection:(float) newSelectionTime timeSpan:(float) timeSpan;
-(float) selectionStartTime;
-(float) selectionEndTime;
-(void)  endSelection;
-(BOOL)  selecting;
-(float) rmsOfSelection;
-(void)  changeHeartActive:(BOOL) active;
-(BOOL)  thresholding;
-(float) threshold;
-(void)  setThreshold:(float)newThreshold;

@end
