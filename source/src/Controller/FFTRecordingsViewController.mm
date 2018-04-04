//
//  FFTRecordingsViewController.m
//  Spike Recorder
//
//  Created by Stanislav Mircic on 2/22/18.
//  Copyright © 2018 BackyardBrains. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FFTRecordingsViewController.h"

@interface FFTRecordingsViewController ()
{
    NSTimer * touchTimer;
    BOOL backButtonActive;
    dispatch_source_t callbackTimer; //timer for update of slider/scrubber
}

@end

@implementation FFTRecordingsViewController

@synthesize bbfile;
@synthesize timeSlider;
@synthesize playPauseButton;

#pragma mark - View management
- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
    self.timeSlider.continuous = YES;
    [self.timeSlider addTarget:self
                        action:@selector(sliderTouchUpInside:)
              forControlEvents:(UIControlEventTouchUpInside)];
    [self.timeSlider addTarget:self
                        action:@selector(sliderTouchDown:)
              forControlEvents:(UIControlEventTouchDown)];
    [self.timeSlider addTarget:self
                        action:@selector(sliderTouchUpOutside:)
              forControlEvents:(UIControlEventTouchUpOutside)];
    [self.timeSlider addTarget:self
                        action:@selector(sliderTouchCancel:)
              forControlEvents:(UIControlEventTouchCancel)];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[self navigationController] setNavigationBarHidden:YES animated:NO];
    
    // start playing file, initializes the file and buffers audio and initialize FFT
    [[BBAudioManager bbAudioManager] startDynanimcFFTForRecording:bbfile];
    
    [[BBAudioManager bbAudioManager] addObserver:self forKeyPath:@"playing" options:NSKeyValueObservingOptionNew context:NULL];
    
    // Set the slider to have the bounds of the audio file's duraiton
    timeSlider.minimumValue = 0;
    timeSlider.maximumValue = [BBAudioManager bbAudioManager].fileDuration;
    // Periodically poll for the current position in the audio file, and update the slider accordingly.
    callbackTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(callbackTimer, dispatch_walltime(NULL, 0), 0.25*NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(callbackTimer, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.timeSlider.isTracking)
                [self.timeSlider setValue:[BBAudioManager bbAudioManager].currentFileTime];
        });
    });

    dispatch_resume(callbackTimer);
    

    
    //Config GL view
    if(glView)
    {
        [glView stopAnimation];
        [glView removeFromSuperview];
        [glView release];
        glView = nil;
    }

    float maxTime = MAX_NUMBER_OF_FFT_SEC;
    glView = [[DynamicFFTCinderGLView alloc] initWithFrame:self.view.frame];
    float baseFreq = 0.5*((float)[[BBAudioManager bbAudioManager] sourceSamplingRate])/((float)[[BBAudioManager bbAudioManager] lengthOfFFTData]);
    [glView setupWithBaseFreq:baseFreq lengthOfFFT:[[BBAudioManager bbAudioManager] lengthOf30HzData] numberOfGraphs:[[BBAudioManager bbAudioManager] lenghtOfFFTGraphBuffer] maxTime:maxTime];
    [[BBAudioManager bbAudioManager] selectChannel:0];
    glView.masterDelegate = self;
    _channelBtn.hidden = [[BBAudioManager bbAudioManager] sourceNumberOfChannels]<2;
    [self.view addSubview:glView];
    [self.view sendSubviewToBack:glView];
    [self initConstrainsForGLView];
    [glView startAnimation];
    [self updatePlayPauseButtonIcon];
    
    //autorange vertical scale on double tap
    UITapGestureRecognizer *doubleTap = [[[UITapGestureRecognizer alloc] initWithTarget: self action:@selector(doubleTapHandler)] autorelease];
    doubleTap.numberOfTapsRequired = 2;
    [glView addGestureRecognizer:doubleTap];
    [self doubleTapHandler];
    
    //Bluetooth notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reSetupScreen) name:RESETUP_SCREEN_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self startBackButtonCountdown];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[self navigationController] setNavigationBarHidden:NO animated:NO];
    NSLog(@"Stopping regular view");
    [[NSNotificationCenter defaultCenter] removeObserver:self name:RESETUP_SCREEN_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [glView stopAnimation];
    [[BBAudioManager bbAudioManager] stopFFT];
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

#pragma mark - App management

-(void) applicationDidBecomeActive:(UIApplication *)application {
    NSLog(@"\n\nApp will become active - FFT view\n\n");
    if(glView)
    {
        [glView startAnimation];
    }
}

-(void) applicationWillResignActive:(UIApplication *)application {
    NSLog(@"\n\nResign active - FFT view\n\n");
    [glView stopAnimation];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    NSLog(@"Terminating... FFT view");
    [glView stopAnimation];
}

#pragma mark - Init/Reset

-(void) reSetupScreen
{
    NSLog(@"Resetup screen");
   
    //Config GL view
    if(glView)
    {
        [glView stopAnimation];
        [glView removeFromSuperview];
        [glView release];
        glView = nil;
    }
     [[BBAudioManager bbAudioManager] startDynanimcFFTForRecording:bbfile];
    float maxTime = 10.0f;
    glView = [[DynamicFFTCinderGLView alloc] initWithFrame:self.view.frame];
    float baseFreq = 0.5*((float)[[BBAudioManager bbAudioManager] sourceSamplingRate])/((float)[[BBAudioManager bbAudioManager] lengthOfFFTData]);
    [glView setupWithBaseFreq:baseFreq lengthOfFFT:[[BBAudioManager bbAudioManager] lengthOf30HzData] numberOfGraphs:[[BBAudioManager bbAudioManager] lenghtOfFFTGraphBuffer] maxTime:maxTime];
    [[BBAudioManager bbAudioManager] selectChannel:0];
    _channelBtn.hidden = [[BBAudioManager bbAudioManager] sourceNumberOfChannels]<2;
    [self.view addSubview:glView];
    [self.view sendSubviewToBack:glView];
    [glView startAnimation];
}

-(void) initConstrainsForGLView
{
    if(glView)
    {
        if (@available(iOS 11, *))
        {
            glView.translatesAutoresizingMaskIntoConstraints = NO;
            
            UILayoutGuide * guide = self.view.safeAreaLayoutGuide;
            
            [glView.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor].active = YES;
            [glView.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor].active = YES;
            [glView.topAnchor constraintEqualToAnchor:guide.topAnchor].active = YES;
            [glView.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor].active = YES;
            // Refresh myView and/or main view
            [self.view layoutIfNeeded];
        }
    }
}

#pragma mark - UI handlers

- (IBAction)backButtonPressed:(id)sender
{
    if(touchTimer)
    {
        [touchTimer invalidate];
        touchTimer = nil;
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)sliderValueChanged:(id)sender
{
    NSLog(@"Slider changed ------ %f",(float)self.timeSlider.value);
     //[BBAudioManager bbAudioManager].currentFileTime = (float)self.timeSlider.value;
    
    [[BBAudioManager bbAudioManager] setSeekTime:(float)self.timeSlider.value];
}

//
// Called when user stop dragging scruber
//
- (void)sliderTouchUpInside:(NSNotification *)notification {
    
    NSLog(@"Slider Touch up inside");
    [[BBAudioManager bbAudioManager] enableFFTForSeeking:YES];
    if([BBAudioManager bbAudioManager].playing)
    {
        [[BBAudioManager bbAudioManager] setSeeking:NO];
        [[BBAudioManager bbAudioManager] resumePlaying];
    }
}

//
// Called when user start dragging scruber
//
- (void)sliderTouchDown:(NSNotification *)notification {
    [[BBAudioManager bbAudioManager] enableFFTForSeeking:NO];
    [[BBAudioManager bbAudioManager] setSeeking:YES];
    [[BBAudioManager bbAudioManager] pausePlaying];
}

//
// Called when user stop dragging scruber
//
- (void) sliderTouchUpOutside:(NSNotification *)notification {
    NSLog(@"Slider Touch up outside");
    [[BBAudioManager bbAudioManager] enableFFTForSeeking:YES];
}


//
// Called when user stop dragging scruber
//
- (void) sliderTouchCancel:(NSNotification *)notification {
    NSLog(@"Slider Tuch Cancel");
    [[BBAudioManager bbAudioManager] enableFFTForSeeking:YES];
}



- (IBAction)playPauseButtonPressed:(id)sender {
    [self togglePlayback];
}



- (void)togglePlayback
{
    if ([BBAudioManager bbAudioManager].playing == false) {
        
        [[BBAudioManager bbAudioManager] resumePlaying];
    }
    else {
        [[BBAudioManager bbAudioManager] pausePlaying];
    }
}

-(void) doubleTapHandler
{
    [glView autorangeSelectedChannel];
}

#pragma mark - Channel code

- (IBAction)channelBtnClick:(id)sender {
    SAFE_ARC_RELEASE(popover); popover=nil;
    
    [self startBackButtonCountdown];
    //the controller we want to present as a popover
    BBChannelSelectionTableViewController *controller = [[BBChannelSelectionTableViewController alloc] initWithStyle:UITableViewStylePlain];
    
    controller.delegate = self;
    popover = [[FPPopoverController alloc] initWithViewController:controller];
    popover.border = NO;
    popover.tint = FPPopoverWhiteTint;
    
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        popover.contentSize = CGSizeMake(300, 500);
    }
    else {
        popover.contentSize = CGSizeMake(200, 300);
    }
    
    popover.arrowDirection = FPPopoverArrowDirectionAny;
    [popover presentPopoverFromView:sender];
}


-(NSMutableArray *) getAllRows
{
    NSMutableArray * allChannelsLabels = [[[NSMutableArray alloc] init] autorelease];
    for(int i=0;i<[[BBAudioManager bbAudioManager] sourceNumberOfChannels];i++)
    {
        [allChannelsLabels addObject:[NSString stringWithFormat:@"Channel %d",i+1]];
    }
    return allChannelsLabels;
}


- (void)rowSelected:(NSInteger) rowIndex
{
    [[BBAudioManager bbAudioManager] selectChannel:rowIndex];
    [popover dismissPopoverAnimated:YES];
    [self startBackButtonCountdown];
}


#pragma mark - Audio Manager observer handler

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"playing"])
    {
        [self updatePlayPauseButtonIcon];
    }
}


-(void) updatePlayPauseButtonIcon
{
    if ([BBAudioManager bbAudioManager].playing == YES)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.playPauseButton setBackgroundImage:[UIImage imageNamed:@"Pause"] forState:UIControlStateNormal];
        });
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.playPauseButton setBackgroundImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
        });
    }
}


#pragma mark - DynamicFFTProtocolDelegate methods

-(void) glViewTouched
{
    if(!backButtonActive)
    {
        bool hideChannelButton = [[BBAudioManager bbAudioManager] sourceNumberOfChannels]<2;
        [UIView animateWithDuration:0.7  delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             backButtonActive = YES;
                             self.backButton.alpha = 1;
                             self.backButton.hidden = NO;
                             self.channelBtn.alpha = 1;
                             _channelBtn.hidden = hideChannelButton;
                         } completion:^(BOOL finished) {
                             [self startBackButtonCountdown];
                         }];
    }
    else
    {
        [self startBackButtonCountdown];
    }
}

-(bool) areWeInFileMode
{
    return YES;
}

#pragma mark - Back button show/hide

-(void) startBackButtonCountdown
{
    if(touchTimer)
    {
        [touchTimer invalidate];
        touchTimer = nil;
    }
    touchTimer = [NSTimer scheduledTimerWithTimeInterval:4 target:self selector:@selector(hideBackButton) userInfo:nil repeats:NO] ;
}

-(void) hideBackButton
{
    [touchTimer invalidate];
    touchTimer = nil;
    [UIView animateWithDuration:1.0  delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         backButtonActive = NO;
                         self.backButton.alpha = 0;
                         self.channelBtn.alpha = 0;
                     } completion:^(BOOL finished) {
                         self.backButton.hidden = YES;
                         self.channelBtn.hidden = YES;
                     }];
}

#pragma mark - Destroy view

- (void)dealloc {
    [_channelBtn release];
    [_backButton release];
    [bbfile release];
    [timeSlider release];
    [playPauseButton release];
    [super dealloc];
}

@end
