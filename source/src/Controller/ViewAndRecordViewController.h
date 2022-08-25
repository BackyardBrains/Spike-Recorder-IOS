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
#import "ConfigViewController.h"

@interface ViewAndRecordViewController : CCGLTouchViewController <MultichannelGLViewDelegate, UIPopoverPresentationControllerDelegate, ConfigViewControllerDelegate>
{
    UIPopoverPresentationController *popController;
    UIPopoverPresentationController * popControllerIpad;
}

@property (retain, nonatomic) IBOutlet UIButton *configButton;
@property (retain, nonatomic) IBOutlet UIButton *recordButton;
@property (retain, nonatomic) IBOutlet UIButton *stopButton;
@property (retain, nonatomic) IBOutlet UIButton *fftButton;
@property (retain, nonatomic) IBOutlet UIButton *p300Button;
@property (retain, nonatomic) IBOutlet UIButton *audioButton;

// view handlers
- (IBAction)stopRecording:(id)sender;
- (IBAction)startRecording:(id)sender;
- (IBAction)configButtonPressed:(id)sender;
- (IBAction)fftButtonPressed:(id)sender;
- (IBAction)p300ButtonPressed:(id)sender;
- (IBAction)soundButtonPressed:(id)sender;

//GL view stuff
@property (retain, nonatomic) MultichannelCindeGLView *glView;
- (void)setGLView:(MultichannelCindeGLView *)view;

//MultichannelGLViewDelegate stuff
-(void) selectChannel:(int) selectedChannel;
-(NSMutableArray *) getEvents;

//Config popup stuff
-(void) setVisibilityForConfigButton:(BOOL) setVisible;
-(void) finishedWithConfiguration;//delegate for custom filter
-(void) configIsClossing;//delegate for custom filter
@end
