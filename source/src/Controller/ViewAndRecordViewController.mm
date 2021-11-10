//
// BackyardBrains
//
// ViewAndRecordViewController.mm
//
// View and Record controller used for real time view and recording
//
//  More info on the CCGLTouch project >> http://www.smallab.org/code/ccgl-touch/
//

#import "ViewAndRecordViewController.h"
#import "FFTViewController.h"
#import "ConfigViewController.h"

@interface ViewAndRecordViewController()
{
    BBFile *aFile;
    dispatch_source_t _timer;
    float recordingTime;
}
@end

@implementation ViewAndRecordViewController

#pragma mark - Components and variables

@synthesize recordButton;
@synthesize glView;
@synthesize configButton;
@synthesize stopButton;
@synthesize fftButton;

#pragma mark - View management

- (void)viewDidLoad
{
    NSLog(@"viewDidLoad View and Record");
    [super viewDidLoad];
}

- (void)viewDidUnload {
    NSLog(@"viewDidUnload View and Record");
    [self setRecordButton:nil];
    [self setStopButton:nil];
    [self setConfigButton:nil];
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    NSLog(@"viewWillAppear - View And Record");
    //[[BBAudioManager bbAudioManager] startMonitoring];

    if(glView)
    {
        [glView stopAnimation];
    }
    else
    {
        //this will execute just first time the app is opened
        glView = [[MultichannelCindeGLView alloc] initWithFrame:self.view.frame];
        [self.view addSubview:glView];
        [self.view sendSubviewToBack:glView];        
        [self initConstrainsForGLView];
     
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reSetupScreen:) name:RESETUP_SCREEN_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newDeviceActivated:) name:NEW_DEVICE_ACTIVATED object:nil];
    
    [self setGLView:glView];
    glView.mode = MultichannelGLViewModeView;
    
    NSLog(@"ViewAndRecord - set number of channesl");
    
    [glView setNumberOfChannels: [[BBAudioManager bbAudioManager] numberOfActiveChannels ] samplingRate:[[BBAudioManager bbAudioManager] sourceSamplingRate] andDataSource:self];
    [[BBAudioManager bbAudioManager] startAquiringInputs:[[BBAudioManager bbAudioManager] currentlyActiveInputDevice]];
    NSLog(@"ViewAndRecord - start animation");
	
    
    UITapGestureRecognizer *doubleTap = [[[UITapGestureRecognizer alloc] initWithTarget: self action:@selector(autorangeView)] autorelease];
    doubleTap.numberOfTapsRequired = 2;
    [glView addGestureRecognizer:doubleTap];
 
    NSLog(@"ViewAndRecord -add notifications");

    CGRect stopButtonRect = CGRectMake(self.stopButton.frame.origin.x, -self.stopButton.frame.size.height, self.stopButton.frame.size.width, self.stopButton.frame.size.height);
    [self.stopButton setFrame:stopButtonRect];
    
    [super viewWillAppear:animated];
    
  
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showUnknownMfiDevice:) name:CAN_NOT_FIND_CONFIG_FOR_DEVICE object:nil];
    
    [glView startAnimation];
}


- (void)viewDidAppear:(BOOL)animated
{
    NSLog(@"viewDidAppear - View And Record");
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    NSLog(@"viewWillDisappear - View And Record");
    [glView stopAnimation];
    NSLog(@"Stopping regular view");
    [glView saveSettings:FALSE]; // save non-threshold settings

    [[NSNotificationCenter defaultCenter] removeObserver:self name:RESETUP_SCREEN_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NEW_DEVICE_ACTIVATED object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:CAN_NOT_FIND_CONFIG_FOR_DEVICE object:nil];
    [super viewWillDisappear:animated];
}


#pragma mark - App management

-(void) applicationDidBecomeActive:(UIApplication *)application {
    NSLog(@"App will become active - ViewRecord");
    if(glView)
    {
        [glView startAnimation];
    }
}

-(void) applicationWillResignActive:(UIApplication *)application {
    NSLog(@"\n\nResign active - ViewRecord\n\n");
     [glView stopAnimation];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    NSLog(@"Terminating...");
    [glView saveSettings:FALSE];
    [glView stopAnimation];
}


#pragma mark - Init/Reset

-(void) newDeviceActivated:(id) object
{
    float currentDefaultTimescale = [[BBAudioManager bbAudioManager] getDefaultTimeScale];
    if(glView)
    {
        [glView setCurrentTimeScale:currentDefaultTimescale];
        [glView setCurrentVoltageScaleToDefault];
    }
}

-(void) reSetupScreen:(id) object
{
    NSLog(@"Resetup screen - View And Record View Controller");
    if(glView)
    {
        [glView stopAnimation];
        
    }
    else
    {
        glView = [[MultichannelCindeGLView alloc] initWithFrame:self.view.frame];
        [self.view addSubview:glView];
        [self.view sendSubviewToBack:glView];
        [self initConstrainsForGLView];
    }
    
    [glView setNumberOfChannels: [[BBAudioManager bbAudioManager] numberOfActiveChannels] samplingRate:[[BBAudioManager bbAudioManager] sourceSamplingRate] andDataSource:self];
    glView.mode = MultichannelGLViewModeView;
    
    
    UITapGestureRecognizer *doubleTap = [[[UITapGestureRecognizer alloc] initWithTarget: self action:@selector(autorangeView)] autorelease];
    doubleTap.numberOfTapsRequired = 2;
    [glView addGestureRecognizer:doubleTap];
    
    // set our view controller's prop that will hold a pointer to our newly created CCGLTouchView
    [self setGLView:glView];
    [glView startAnimation];
    
}

- (void)setGLView:(MultichannelCindeGLView *)view
{
    glView = view;
}

-(void) autorangeView
{
    [glView autorangeSelectedChannel];
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


#pragma mark - MultichannelGLViewDelegate function
- (float) fetchDataToDisplay:(float *)data numFrames:(UInt32)numFrames whichChannel:(UInt32)whichChannel
{
    //Fetch data and get time of data as precise as posible. Used to sichronize
    //display of waveform and spike marks
    return [[BBAudioManager bbAudioManager] fetchAudio:data numFrames:numFrames whichChannel:whichChannel stride:1];
}

-(void) selectChannel:(int) selectedChannel
{
    [[BBAudioManager bbAudioManager] selectChannel:selectedChannel];
}

-(NSMutableArray *) getEvents
{
    return [[BBAudioManager bbAudioManager] getEvents];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

- (IBAction)startRecording:(id)sender
{
    CGRect stopButtonRect;
    
    
    if (@available(iOS 11.0, *))
    {
        
        float originY = self.recordButton.bounds.origin.y;
        float heightButton = self.recordButton.bounds.size.height;
        float safeTop = self.view.safeAreaInsets.top;
        stopButtonRect = CGRectMake(
                                    0,
                                    0,
                                    self.stopButton.bounds.size.width,
                                    safeTop+originY+heightButton+2
                                    );
        
    }
    else
    {
        stopButtonRect = CGRectMake(self.stopButton.frame.origin.x, 0.0f, self.stopButton.frame.size.width, self.stopButton.frame.size.height);
        
    }
    
    self.stopButton.titleLabel.numberOfLines = 2; // Dynamic number of lines
    self.stopButton.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.stopButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.stopButton setTitle:  @"Tap to Stop Recording" forState: UIControlStateNormal];
    
    
    //Make timer that we are displaying while recording
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    if (_timer)
    {
        recordingTime = 0.0f;
        dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), 0.1 * NSEC_PER_SEC, (1ull * NSEC_PER_SEC) / 10);
        dispatch_source_set_event_handler(_timer, ^{
            recordingTime+=0.1f;
            float duration = recordingTime;
            float seconds = fmod(duration, 60.0);
            double minutes = fmod(trunc(duration / 60.0), 60.0);
            //update label
            [self.stopButton setTitle:  [NSString stringWithFormat:@"Tap to Stop Recording \n%02.0f:%04.1f", minutes, seconds] forState: UIControlStateNormal];
        });
        dispatch_resume(_timer);
    }
    
    [UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.25];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[self.stopButton setFrame:stopButtonRect];
	[UIView commitAnimations];
    [self.view bringSubviewToFront:self.stopButton];
    
    BBAudioManager *bbAudioManager = [BBAudioManager bbAudioManager];
    if (bbAudioManager.recording == false) {
        
        //check if we have non-standard requirements for format and make custom wav
        if([bbAudioManager numberOfActiveChannels]>2 || [bbAudioManager sourceSamplingRate]!=44100.0f)
        {
            aFile = [[BBFile alloc] initWav];
        }
        else
        {
            //if everything is standard make .m4a file (it has beter compression )
            aFile = [[BBFile alloc] init];
        }
        aFile.numberOfChannels = [bbAudioManager numberOfActiveChannels];
        aFile.samplingrate = [bbAudioManager sourceSamplingRate];
        [aFile setupChannels];//create name of channels without spike trains
        
        NSLog(@"URL: %@", [aFile fileURL]);
        [bbAudioManager startRecording:aFile];
        recordingTime = 0.0f;
    }
}

- (IBAction)stopRecording:(id)sender {
    
    if (_timer) {
        dispatch_source_cancel(_timer);
        // Remove this if you are on a Deployment Target of iOS6 or OSX 10.8 and above
        dispatch_release(_timer);
        _timer = nil;
    }
	float offset = self.stopButton.frame.size.height;
	CGRect stopButtonRect = CGRectMake(self.stopButton.frame.origin.x, -offset, self.stopButton.frame.size.width, self.stopButton.frame.size.height);
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.25];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
	[self.stopButton setFrame:stopButtonRect];
	[UIView commitAnimations];
    
    BBAudioManager *bbAudioManager = [BBAudioManager bbAudioManager];
    aFile.filelength = bbAudioManager.fileDuration;
    [bbAudioManager stopRecording];
    [aFile save];
    [aFile release];
}

#pragma mark - Config button stuff

-(void) setVisibilityForConfigButton:(BOOL) setVisible
{
    setVisible = YES;
    self.configButton.hidden = !setVisible;
    //self.configButton.hidden = NO;
    int filterSettings = [[BBAudioManager bbAudioManager] currentFilterSettings];
    if(filterSettings == FILTER_SETTINGS_EEG || filterSettings == FILTER_SETTINGS_RAW || filterSettings == FILTER_SETTINGS_CUSTOM || [[BBAudioManager bbAudioManager] externalAccessoryIsActive])
    {
        self.fftButton.hidden = !setVisible;
    }
    else
    {
        self.fftButton.hidden = YES;
    }
    //self.fftButton.hidden = NO;//debug
}

- (IBAction)configButtonPressed:(id)sender {
    

    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
    {
        ConfigViewController *controller = [[ConfigViewController alloc] initWithNibName:@"ConfigViewController" bundle:nil];
        controller.masterDelegate = self;
        controller.modalPresentationStyle = UIModalPresentationPopover;
        controller.preferredContentSize = CGSizeMake(500, 700);
        
        // configure the Popover presentation controller
        popControllerIpad = [controller popoverPresentationController];
        
        popControllerIpad.delegate = self;
        popControllerIpad.permittedArrowDirections = 0;
        CGRect sourceRect = CGRectZero;
        sourceRect.origin.x = CGRectGetMidX(self.view.bounds)-self.view.frame.origin.x/2.0;
        sourceRect.origin.y = CGRectGetMidY(self.view.bounds)-self.view.frame.origin.y/2.0;
        popControllerIpad.sourceRect =  sourceRect;
        popControllerIpad.sourceView = self.view;
        [self presentViewController:controller animated:YES completion:nil];
        
    }
    else
    {
        ConfigViewController *controller = [[ConfigViewController alloc] initWithNibName:@"ConfigViewController" bundle:nil];
        controller.masterDelegate = self;
        controller.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:controller animated:YES completion:nil];
    }  
}


- (void)popoverPresentationController:(UIPopoverPresentationController *)popoverPresentationController
          willRepositionPopoverToRect:(inout CGRect *)rect
                               inView:(inout UIView * _Nonnull *)view
{
    if(popoverPresentationController == popController)
    {
            if (UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation) && (!( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )))
            {
                popController.permittedArrowDirections = UIPopoverArrowDirectionLeft;
                
                popController.sourceRect =  CGRectMake(self.configButton.bounds.origin.x, 0, configButton.bounds.size.width, configButton.bounds.size.height);
            }
            else
            {
                popController.permittedArrowDirections = UIPopoverArrowDirectionUp;
                popController.sourceRect =  CGRectMake(self.configButton.bounds.origin.x, self.configButton.bounds.origin.y, configButton.bounds.size.width, configButton.bounds.size.height);
            }
    }
}


- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    if(popControllerIpad)
    {
        if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
        {
            CGRect sourceRect = CGRectZero;
            sourceRect.origin.x = CGRectGetMidX(self.view.bounds)-self.view.frame.origin.x/2.0;
            sourceRect.origin.y = CGRectGetMidY(self.view.bounds)-self.view.frame.origin.y/2.0;
            popControllerIpad.sourceRect =  sourceRect;
        }
    }
}

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller
{
 return UIModalPresentationNone;
}


//
// Used for custom filter view
//
-(void) finishedWithConfiguration
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - FFT stuff
-(IBAction) fftButtonPressed:(id)sender
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
    UIViewController *controller = [storyboard instantiateViewControllerWithIdentifier:@"fftViewID"];
    [self presentViewController:controller animated:YES completion:nil];
}

#pragma mark - Alerts for user

-(void) showUnknownMfiDevice:(NSNotification *) notification
{
    NSString *detailsText = [NSString stringWithFormat:@"App does not have info about connected device. Please connect to internet and restart application to update device info. (Device Model: %@)", (NSString*) notification.object];
    UIAlertController *alertView = [UIAlertController alertControllerWithTitle:@"Can not recognize device" message:detailsText preferredStyle:UIAlertControllerStyleAlert];
    [alertView addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action)
                            {
                                // OK button tappped. Do nothing
                                [self dismissViewControllerAnimated:YES completion:^{
                                }];
                            }]];
    
    //make so that on iPad alert is displayed in the center of the screen
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        CGRect rectForWindow;
        alertView.popoverPresentationController.sourceView = self.view;
        alertView.popoverPresentationController.permittedArrowDirections = 0;
        rectForWindow = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
        alertView.popoverPresentationController.sourceRect = rectForWindow;
    }

    // Present action sheet.
    [self presentViewController:alertView animated:YES completion:nil];
}

#pragma mark - Memory management

- (void)dealloc
{
    [recordButton release];
    [stopButton release];
    [configButton release];
    [glView release];
    [fftButton release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    NSLog(@"\n\n!Memory Warning! View And Record\n\n");
    // Releases the view if it doesn't have a superview
    [super didReceiveMemoryWarning];
}

@end
