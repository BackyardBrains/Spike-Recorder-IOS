//
// BackyardBrains
//
// ViewAndRecordViewController.h
//
// View and Record controller used for real time view and recording
//

#import "CCGLTouchViewController.h"
#import "BBAudioManager.h"
#import "BBFile.h"
#import "MultichannelCindeGLView.h"
#import "ChooseFilterTypeViewController.h"
#import "FilterSettingsViewController.h"


@interface ViewAndRecordViewController : CCGLTouchViewController <MultichannelGLViewDelegate, UIPopoverPresentationControllerDelegate, ChooseFilterTypeDelegateProtocol, BBFilterConfigDelegate>
{
    UIPopoverPresentationController *popController;
    UIPopoverPresentationController * popControllerIpad;
}

@property (retain, nonatomic) IBOutlet UIButton *configButton;
@property (retain, nonatomic) IBOutlet UIButton *recordButton;
@property (retain, nonatomic) IBOutlet UIButton *stopButton;

// view handlers
- (IBAction)stopRecording:(id)sender;
- (IBAction)startRecording:(id)sender;
- (IBAction)configButtonPressed:(id)sender;

//GL view stuff
@property (retain, nonatomic) MultichannelCindeGLView *glView;
- (void)setGLView:(MultichannelCindeGLView *)view;

//MultichannelGLViewDelegate stuff
-(void) selectChannel:(int) selectedChannel;

//Config popup stuff
-(void) setVisibilityForConfigButton:(BOOL) setVisible;
-(void) endSelectionOfFilters:(int) filterType;
-(void) finishedWithConfiguration;//delegate for custom filter

@end
