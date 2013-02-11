
#import "CCGLTouchViewController.h"
#import "MyCinderGLView.h"
#import "BBAudioManager.h"

@interface ThresholdViewController : CCGLTouchViewController {
    MyCinderGLView *glView;
}

@property (retain, nonatomic) IBOutlet UILabel *triggerHistoryLabel;
- (void)setGLView:(CCGLTouchView *)view;
- (IBAction)updateNumTriggersInThresholdHistory:(id)sender;


@end
