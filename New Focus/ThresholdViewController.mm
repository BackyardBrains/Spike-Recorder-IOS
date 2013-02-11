
#import "ThresholdViewController.h"

@interface ThresholdViewController() {
    dispatch_source_t callbackTimer;
}

@end

@implementation ThresholdViewController
@synthesize triggerHistoryLabel;

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[BBAudioManager bbAudioManager] startThresholding:8192];
    [glView startAnimation];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [[BBAudioManager bbAudioManager] stopThresholding];
    [glView stopAnimation];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // our CCGLTouchView being added as a subview
	MyCinderGLView *aView = [[MyCinderGLView alloc] init];
	glView = aView;
	[aView release];
    glView = [[MyCinderGLView alloc] initWithFrame:self.view.frame];
    
	[self.view addSubview:glView];
    [self.view sendSubviewToBack:glView];
    
	
    // set our view controller's prop that will hold a pointer to our newly created CCGLTouchView
    [self setGLView:glView];
    

}

- (void)setGLView:(MyCinderGLView *)view
{
    glView = view;
    callbackTimer = nil;
}

- (IBAction)updateNumTriggersInThresholdHistory:(id)sender
{
    UISlider *theSlider = (UISlider *)sender;
    int newHistoryLength = (int)theSlider.value;
    [[BBAudioManager bbAudioManager] setNumTriggersInThresholdHistory:newHistoryLength];
    triggerHistoryLabel.text = [NSString stringWithFormat:@"%dx", newHistoryLength];
    
    
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}



- (void)dealloc {
    [triggerHistoryLabel release]; 
    [super dealloc];
}

- (void)viewDidUnload {
    [self setUpdateNumTriggersInThresholdHistory:nil];
    [triggerHistoryLabel release];
    triggerHistoryLabel = nil;
    [self setTriggerHistoryLabel:nil];
    [super viewDidUnload];
}
@end