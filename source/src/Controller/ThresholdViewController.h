
#import "CCGLTouchViewController.h"
#import "BBAudioManager.h"
#import "MultichannelCindeGLView.h"

@interface ThresholdViewController : CCGLTouchViewController <MultichannelGLViewDelegate> {
    
}

@property (retain, nonatomic) IBOutlet UILabel *triggerHistoryLabel;
@property (retain, nonatomic) MultichannelCindeGLView *glView;
- (void)setGLView:(MultichannelCindeGLView *)view;
- (IBAction)updateNumTriggersInThresholdHistory:(id)sender;

-(BOOL) thresholding;
-(void) selectChannel:(int) selectedChannel;
-(float) threshold;

- (void)setThreshold:(float)newThreshold;
- (float) fetchDataToDisplay:(float *)data numFrames:(UInt32)numFrames whichChannel:(UInt32)whichChannel;

-(BOOL) shouldEnableSelection;
-(void) updateSelection:(float) newSelectionTime timeSpan:(float) timeSpan;
-(float) selectionStartTime;
-(float) selectionEndTime;
-(void) endSelection;
-(BOOL) selecting;
-(float) rmsOfSelection;

@end
