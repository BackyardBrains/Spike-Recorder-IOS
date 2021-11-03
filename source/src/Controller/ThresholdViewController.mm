//
// BackyardBrains
//
// ThresholdViewController.mm
//
// Threshold and average signal based on threshold level
// Shows BPM for heart rate
//

#import "ThresholdViewController.h"
#import "BBECGAnalysis.h"

@interface ThresholdViewController()
{
    BOOL lastHearRateActive;
}
@end

@implementation ThresholdViewController

#pragma mark - Components and variables
@synthesize triggerHistoryLabel;
@synthesize activeHeartImg;
@synthesize glView;

#pragma mark - View Management

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewDidUnload {
    [triggerHistoryLabel release];
    triggerHistoryLabel = nil;
    [self setTriggerHistoryLabel:nil];
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    NSLog(@"Starting threshold view");
    [super viewWillAppear:animated];
    
    self.activeHeartImg.image = [UIImage imageNamed:@"nobeat.png"];
    [self hideShowHeartIcon];
    lastHearRateActive = NO;
    
    if(glView)
    {
        [glView stopAnimation];
    }

    if(glView == nil)
    {
        glView = [[MultichannelCindeGLView alloc] initWithFrame:self.view.frame];
        [self.view addSubview:glView];
        [self.view sendSubviewToBack:glView];
        [self initConstrainsForGLView];
    }
    glView.mode = MultichannelGLViewModeThresholding;
    [glView setNumberOfChannels: [[BBAudioManager bbAudioManager] numberOfActiveChannels ] samplingRate:[[BBAudioManager bbAudioManager] sourceSamplingRate] andDataSource:self];
    [[BBAudioManager bbAudioManager] startThresholding:8192];

    // set our view controller's prop that will hold a pointer to our newly created CCGLTouchView
    [self setGLView:glView];
    [glView loadSettings:TRUE];
   

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reSetupScreen) name:RESETUP_SCREEN_NOTIFICATION object:nil];
     [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(beatTheHeart) name:HEART_BEAT_NOTIFICATION object:nil];
    
    [glView startAnimation];
}

- (void)viewWillDisappear:(BOOL)animated
{
    NSLog(@"viewWillDisappear threshold");
    [glView saveSettings:TRUE];
    [[BBAudioManager bbAudioManager] saveSettingsToUserDefaults];
    [[BBAudioManager bbAudioManager] stopThresholding];
    [glView stopAnimation];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:RESETUP_SCREEN_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:HEART_BEAT_NOTIFICATION object:nil];

    [super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

#pragma mark - App management

-(void) applicationDidBecomeActive:(UIApplication *)application {
    NSLog(@"\n\nApp will become active - Threshold\n\n");
    if(glView)
    {
        [glView startAnimation];
        [[BBAudioManager bbAudioManager] startThresholding:8192];
    }
}

-(void) applicationWillResignActive:(UIApplication *)application {
    NSLog(@"\n\nResign active - Threshold\n\n");
    [glView stopAnimation];
    [[BBAudioManager bbAudioManager] stopThresholding];
}


- (void)applicationWillTerminate:(UIApplication *)application {
    NSLog(@"Terminating from threshold app...");
    [glView saveSettings:TRUE];
    [[BBAudioManager bbAudioManager] saveSettingsToUserDefaults];
    [glView stopAnimation];
    [[BBAudioManager bbAudioManager] stopThresholding];
}

#pragma mark - Init/Reset

-(void) reSetupScreen
{
    NSLog(@"Resetup screen");
    if(glView)
    {
        [glView stopAnimation];
    }
    
    if(glView == nil)
    {
        glView = [[MultichannelCindeGLView alloc] initWithFrame:self.view.frame];
        [self.view addSubview:glView];
        [self.view sendSubviewToBack:glView];
        [self initConstrainsForGLView];
    }
    
    glView.mode = MultichannelGLViewModeThresholding;
    [glView setNumberOfChannels: [[BBAudioManager bbAudioManager] numberOfActiveChannels ] samplingRate:[[BBAudioManager bbAudioManager] sourceSamplingRate] andDataSource:self];
    [[BBAudioManager bbAudioManager] startThresholding:8192];
    
    
    // set our view controller's prop that will hold a pointer to our newly created CCGLTouchView
    [self setGLView:glView];
    [glView startAnimation];
}


- (void)setGLView:(MultichannelCindeGLView *)view
{
    glView = view;
}

-(void) initConstrainsForGLView
{
    if(glView)
    {
        if (@available(iOS 11, *))
        {
            glView.translatesAutoresizingMaskIntoConstraints = NO;
            
            UILayoutGuide * guide = self.view.safeAreaLayoutGuide;
            [self.glView.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor].active = YES;
            [self.glView.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor].active = YES;
            [self.glView.topAnchor constraintEqualToAnchor:guide.topAnchor].active = YES;
            [self.glView.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor].active = YES;
            // Refresh myView and/or main view
            [self.view layoutIfNeeded];
        }
    }
}

#pragma mark - Heart rate 

//
// Trigger animation of beating heart
//
-(void) beatTheHeart
{
     dispatch_async(dispatch_get_main_queue(), ^{
         [self hideShowHeartIcon];
    
        self.activeHeartImg.alpha = 0.2;
        [UIView animateWithDuration:0.2
                        animations:^(void)
                        {
                             self.activeHeartImg.alpha = 1.0;
                        }
                        completion:^ (BOOL finished)
                        {
                             if (finished) {
                                 [UIView animateWithDuration:0.3 animations:^(void){
                                     // Revert image view to original.
                                     self.activeHeartImg.alpha = 0.2;
                                     [self.activeHeartImg.layer removeAllAnimations];
                                     [self.activeHeartImg setNeedsDisplay];
                                 }];
                             }
                        }
         ];
    });
}

-(void) hideShowHeartIcon
{
    if([[BBAudioManager bbAudioManager] currentFilterSettings]==FILTER_SETTINGS_EKG && [[BBAudioManager bbAudioManager] amDemodulationIsON])
    {
        self.activeHeartImg.hidden = NO;
    }
    else
    {
        self.activeHeartImg.hidden = YES;
    }
}

-(void) changeHeartActive:(BOOL) active
{
    [self hideShowHeartIcon];
    
    if(lastHearRateActive!=active)
    {
        lastHearRateActive= active;
        if(active)
        {
            self.activeHeartImg.image = [UIImage imageNamed:@"hasbeat.png"];
        }
        else
        {
            self.activeHeartImg.image = [UIImage imageNamed:@"nobeat.png"];
            self.activeHeartImg.alpha = 0.8;
        }
    }
}

#pragma mark - MultichannelGLViewDelegate function

- (float) fetchDataToDisplay:(float *)data numFrames:(UInt32)numFrames whichChannel:(UInt32)whichChannel
{
    return [[BBAudioManager bbAudioManager] fetchAudio:data numFrames:numFrames whichChannel:whichChannel stride:1];
}

#pragma mark - Selection of interval

-(BOOL) shouldEnableSelection
{
    return ![[BBAudioManager bbAudioManager] playing];
}

-(void) updateSelection:(float) newSelectionTime timeSpan:(float) timeSpan
{
    [[BBAudioManager bbAudioManager] updateSelection:newSelectionTime timeSpan:1.0f];
}

-(float) selectionStartTime
{
    return [[BBAudioManager bbAudioManager] selectionStartTime];
}

-(float) selectionEndTime
{
    return [[BBAudioManager bbAudioManager] selectionEndTime];
}

-(void) endSelection
{
    [[BBAudioManager bbAudioManager] endSelection];
}

-(BOOL) selecting
{
    return [[BBAudioManager bbAudioManager] selecting];
}

-(float) rmsOfSelection
{
    return [[BBAudioManager bbAudioManager] rmsOfSelection];
}

#pragma mark - Thresholding

- (IBAction)updateNumTriggersInThresholdHistory:(id)sender
{
    UISlider *theSlider = (UISlider *)sender;
    int newHistoryLength = (int)theSlider.value;
    [[BBAudioManager bbAudioManager] setNumTriggersInThresholdHistory:newHistoryLength];
    triggerHistoryLabel.text = [NSString stringWithFormat:@"%dx", newHistoryLength];
}

-(BOOL) thresholding
{
    return [[BBAudioManager bbAudioManager] thresholding];
}

-(float) threshold
{
    return [[BBAudioManager bbAudioManager] threshold];
}

- (void)setThreshold:(float)newThreshold
{
    [[BBAudioManager bbAudioManager] setThreshold:newThreshold];
}

-(void) selectChannel:(int) selectedChannel
{
    [[BBAudioManager bbAudioManager] selectChannel:selectedChannel];
}

#pragma mark - Memory management

- (void)dealloc {
    [triggerHistoryLabel release];
    [activeHeartImg release];
    [glView release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning {
    NSLog(@"\n\n!Memory Warning! Threshold\n\n");
    // Releases the view if it doesn't have a superview
    [super didReceiveMemoryWarning];
}



@end
