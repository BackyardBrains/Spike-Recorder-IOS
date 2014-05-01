//
//  MyViewController.mm
//  CCGLTouchBasic example
//
//  Created by Matthieu Savary on 09/09/11.
//  Copyright (c) 2011 SMALLAB.ORG. All rights reserved.
//
//  More info on the CCGLTouch project >> http://www.smallab.org/code/ccgl-touch/
//  License & disclaimer >> see license.txt file included in the distribution package
//

#import "ViewAndRecordViewController.h"
#import "StimulationParameterViewController.h"

@interface ViewAndRecordViewController() {
    dispatch_source_t callbackTimer;
    BBFile *aFile;
    dispatch_source_t _timer;
    float recordingTime;
}

@end

@implementation ViewAndRecordViewController
@synthesize slider;
@synthesize recordButton;
@synthesize stimulateButton;
@synthesize stimulatePreferenceButton;

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[BBAudioManager bbAudioManager] startMonitoring];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL enabled = [[defaults valueForKey:@"stimulationEnabled"] boolValue];

    stimulateButton.hidden = !enabled;
    stimulatePreferenceButton.hidden = !enabled;
    
    [glView startAnimation];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [[BBAudioManager bbAudioManager] setViewAndRecordFunctionalityActive:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[BBAudioManager bbAudioManager] setViewAndRecordFunctionalityActive:NO];
    NSLog(@"Stopping regular view");
    [glView saveSettings:FALSE]; // save non-threshold settings
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
    
    stimulateButton.selected = NO;
    
    // Listen for going down
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    NSLog(@"Terminating...");
    [glView saveSettings:FALSE];
    [glView stopAnimation];
}

- (void)setGLView:(MyCinderGLView *)view
{
    glView = view;
    callbackTimer = nil;
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

- (IBAction)startRecording:(id)sender
{
    CGRect stopButtonRect = CGRectMake(self.stopButton.frame.origin.x, 0.0f, self.stopButton.frame.size.width, self.stopButton.frame.size.height);
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
    
    BBAudioManager *bbAudioManager = [BBAudioManager bbAudioManager];
    if (bbAudioManager.recording == false) {
        aFile = [[BBFile alloc] init];
        NSLog(@"URL: %@", [aFile fileURL]);
        [bbAudioManager startRecording:[aFile fileURL]];
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

- (void)timerTick{
    
    
}


- (IBAction)stimulateButtonPressed:(id)sender {

    BBAudioManager *bbAudioManager = [BBAudioManager bbAudioManager];
    if (bbAudioManager.stimulating == false) {
        NSLog(@"Current stimulation type: %d", bbAudioManager.stimulationType);
        [bbAudioManager startStimulating:bbAudioManager.stimulationType];
        stimulateButton.selected = YES;
    }
    else {
        [bbAudioManager stopStimulating];
        stimulateButton.selected = NO;
    }
}

- (IBAction)stimulatePrefButtonPressed:(id)sender {
    
    StimulationParameterViewController *spvc = [[StimulationParameterViewController alloc] initWithNibName:@"StimulationParameterView" bundle:nil];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:spvc];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        NSLog(@"AWESOME");
        navController.modalPresentationStyle = UIModalPresentationFormSheet;
    }

    [self.tabBarController presentViewController:navController animated:YES completion:nil];
    
    [spvc release];
    [navController release];
    
}


- (void)dealloc {
    [slider release];
    [recordButton release];
    [stimulateButton release];
    [stimulatePreferenceButton release];
    [_stopButton release];
    [super dealloc];
}

- (void)viewDidUnload {
    [self setSlider:nil];
    [self setRecordButton:nil];
    [self setStimulateButton:nil];
    [self setStimulatePreferenceButton:nil];
    [self setStopButton:nil];
    [super viewDidUnload];
}
@end