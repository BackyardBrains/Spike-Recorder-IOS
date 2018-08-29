//
//  PlaybackViewController.m
//
//  Copyright (c) 2012 Backyard Brains. All rights reserved.
//

#import "PlaybackViewController.h"

@interface PlaybackViewController() {
    dispatch_source_t callbackTimer; //timer for update of slider/scrubber
}

- (void)togglePlayback;
- (void)ifNoHeadphonesConfigureAudioToPlayOutOfSpeakers;
- (void)restoreAudioOutputRouteToDefault;

@end

@implementation PlaybackViewController
@synthesize timeSlider;
@synthesize playPauseButton;
@synthesize bbfile;
@synthesize showNavigationBar;
@synthesize glView;

#pragma mark - View management

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.timeSlider.continuous = YES;
    [self.timeSlider addTarget:self
                        action:@selector(sliderTouchUpInside:)
              forControlEvents:(UIControlEventTouchUpInside)];
    [self.timeSlider addTarget:self
                        action:@selector(sliderTouchDown:)
              forControlEvents:(UIControlEventTouchDown)];
}

- (void)viewWillAppear:(BOOL)animated
{
    NSLog(@"\n\nviewWillAppear Playback View Controller\n\n");
    if(showNavigationBar)
    {
        [self.navigationController setNavigationBarHidden:NO animated:NO];
    }
    else
    {
        [self.navigationController setNavigationBarHidden:YES animated:NO];
    }
    if(glView)
    {
        [glView stopAnimation];
    }
    
    // our CCGLTouchView being added as a subview
    if(glView == nil)
    {
        glView = [[MultichannelCindeGLView alloc] initWithFrame:self.view.frame];
        [self.view addSubview:glView];
        [self.view sendSubviewToBack:glView];
        [self initConstrainsForGLView];
    }
    
    glView.mode = MultichannelGLViewModePlayback;
    
    // set our view controller's prop that will hold a pointer to our newly created CCGLTouchView
    [self setGLView:glView];

    [glView setNumberOfChannels: [[BBAudioManager bbAudioManager] sourceNumberOfChannels] samplingRate:[[BBAudioManager bbAudioManager] sourceSamplingRate] andDataSource:self];
    
    UITapGestureRecognizer *doubleTap = [[[UITapGestureRecognizer alloc] initWithTarget: self action:@selector(autorangeView)] autorelease];
    doubleTap.numberOfTapsRequired = 2;
    [glView addGestureRecognizer:doubleTap];
    
    // Make sure that we're playing out of the right audioroute, and if it changes
    // (e.g., if you unplug the headphones while playing), it just works
    [self ifNoHeadphonesConfigureAudioToPlayOutOfSpeakers];
    [[Novocaine audioManager] addObserver:self forKeyPath:@"numOutputChannels" options:NSKeyValueObservingOptionNew context:NULL];
    [[BBAudioManager bbAudioManager] addObserver:self forKeyPath:@"playing" options:NSKeyValueObservingOptionNew context:NULL];
    
    // Grab the audio file, and start buffering audio from it.
    NSURL *theURL = [bbfile fileURL];
    NSLog(@"Playing a file at: %@", theURL);
    [[BBAudioManager bbAudioManager] startPlaying:bbfile]; // startPlaying: initializes the file and buffers audio
    
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    [glView startAnimation];
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    NSLog(@"\n\nviewWillDisappear - Playback\n\n");
    [glView stopAnimation];
    [[BBAudioManager bbAudioManager] clearWaveform];
    
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [glView saveSettings:FALSE]; // save non-threshold settings
    
    
    dispatch_suspend(callbackTimer);
    [[BBAudioManager bbAudioManager] stopPlaying];
    
    [[Novocaine audioManager] removeObserver:self forKeyPath:@"numOutputChannels"];
    [self restoreAudioOutputRouteToDefault];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    
    [super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}


#pragma mark - Application management

-(void) applicationDidBecomeActive:(UIApplication *)application {
    NSLog(@"\n\nApp will become active - Playback\n\n");
    if(glView)
    {
        [glView startAnimation];
    }
}

-(void) applicationWillResignActive:(UIApplication *)application {
    NSLog(@"\n\nResign active - Playback\n\n");
    [glView stopAnimation];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    NSLog(@"Terminating...");
}


#pragma mark - Init/Reset view

- (void)setGLView:(MultichannelCindeGLView *)view
{
    glView = view;
    callbackTimer = nil;
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

-(void) autorangeView
{
    [glView autorangeSelectedChannel];
}

#pragma mark - MultichannelGLViewDelegate functions

- (float) fetchDataToDisplay:(float *)data numFrames:(UInt32)numFrames whichChannel:(UInt32)whichChannel
{

    //Fetch data and get time of data as precise as posible. Used to sichronize
    //display of waveform and spike marks
    return [[BBAudioManager bbAudioManager] fetchAudio:data numFrames:numFrames whichChannel:whichChannel stride:1];
}

-(NSMutableArray *) getChannels
{
    return [[BBAudioManager bbAudioManager] getChannels];
}

-(BOOL) shouldEnableSelection
{
    return ![[BBAudioManager bbAudioManager] playing];
}

-(void) updateSelection:(float) newSelectionTime timeSpan:(float) timeSpan
{
    [[BBAudioManager bbAudioManager] updateSelection:newSelectionTime timeSpan:timeSpan];
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

-(NSMutableArray * ) spikesCount
{
    return [[BBAudioManager bbAudioManager] spikesCount];
}

-(void) selectChannel:(int) selectedChannel
{
    [[BBAudioManager bbAudioManager] selectChannel:selectedChannel];
}

#pragma mark - View handlers

//
// Called when user stop dragging scruber
//
- (void)sliderTouchUpInside:(NSNotification *)notification {
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
    [[BBAudioManager bbAudioManager] setSeeking:YES];
    [[BBAudioManager bbAudioManager] pausePlaying];
}

- (IBAction)sliderValueChanged:(id)sender {
    
    //[BBAudioManager bbAudioManager].currentFileTime = (float)self.timeSlider.value;
    
    [[BBAudioManager bbAudioManager] setSeekTime:(float)self.timeSlider.value];
}

- (IBAction)playPauseButtonPressed:(id)sender
{
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

//Seek to new place in file
- (IBAction)backBtnClick:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"numOutputChannels"])
    {
        // If the input route changes,
        // remember where we were in the playing audio file, and stop playing that file.
        float timeToSeekTo = [BBAudioManager bbAudioManager].currentFileTime;
        [[BBAudioManager bbAudioManager] pausePlaying];
        // Then, make sure that we're either playing through the speaker, or through headphones
        // (never the receiver)
        [self ifNoHeadphonesConfigureAudioToPlayOutOfSpeakers];
        // And finally, start up the audio file again, and seek to where we were.
        [[BBAudioManager bbAudioManager] startPlaying:bbfile]; // startPlaying: initializes the file and buffers audio
        [BBAudioManager bbAudioManager].currentFileTime = timeToSeekTo;
        
    }
    else if ([keyPath isEqualToString:@"playing"])
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
}

#pragma mark - Audio functions

- (void)restoreAudioOutputRouteToDefault
{
    UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_None;
    AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute,
                             sizeof (audioRouteOverride),
                             &audioRouteOverride);
}

- (void)ifNoHeadphonesConfigureAudioToPlayOutOfSpeakers
{
    
    UInt32 propertySize = sizeof(CFStringRef);
    CFStringRef route;
    AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &propertySize, &route);
    
    NSString* routeStr = (NSString*)route;
    NSLog(@"AudioRoute -: %@", routeStr);
    
    /* Known values of route:
     * "Headset"
     * "Headphone"
     * "Speaker"
     * "SpeakerAndMicrophone"
     * "HeadphonesAndMicrophone"
     * "HeadsetInOut"
     * "ReceiverAndMicrophone"
     * "Lineout"
     */
    
    NSRange headphoneRange = [routeStr rangeOfString : @"Headphone"];
    NSRange headsetRange = [routeStr rangeOfString : @"Headset"];
    NSRange receiverRange = [routeStr rangeOfString : @"Receiver"];
    NSRange speakerRange = [routeStr rangeOfString : @"Speaker"];
    NSRange lineoutRange = [routeStr rangeOfString : @"Lineout"];
    NSRange HDMIRange = [routeStr rangeOfString : @"HDMI"];
    
    if (headphoneRange.location != NSNotFound) {
        // Don't change the route if the headphone is plugged in.
        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_None;
        AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute,
                                 sizeof (audioRouteOverride),
                                 &audioRouteOverride);
        
    } else if(headsetRange.location != NSNotFound) {
        // Don't change the route if the headset is plugged in.
        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_None;
        AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute,
                                 sizeof (audioRouteOverride),
                                 &audioRouteOverride);
        
    } else if (receiverRange.location != NSNotFound) {
        NSLog(@"Changing to speaker!");
        // Change to play on the speaker
        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;
        AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute,
                                 sizeof (audioRouteOverride),
                                 &audioRouteOverride);
        
    } else if (speakerRange.location != NSNotFound) {
        // Make sure it's the speaker
        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;
        AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute,
                                 sizeof (audioRouteOverride),
                                 &audioRouteOverride);
        
    } else if (lineoutRange.location != NSNotFound) {
        // Don't change the route if the lineout is plugged in.
        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_None;
        AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute,
                                 sizeof (audioRouteOverride),
                                 &audioRouteOverride);
    }
    else if (HDMIRange.location != NSNotFound) {
        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;
        AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute,
                                 sizeof (audioRouteOverride),
                                 &audioRouteOverride);
    } else {
        NSLog(@"Unknown audio route.");
        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_None;
        AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute,
                                 sizeof (audioRouteOverride),
                                 &audioRouteOverride);
    }
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning {
    NSLog(@"\n\n!Memory Warning! Playback\n\n");
    // Releases the view if it doesn't have a superview
    [super didReceiveMemoryWarning];
}


- (void)dealloc {
    [timeSlider release];
    [glView release];
    [bbfile release];
    [playPauseButton release];
    [super dealloc];
}
@end
