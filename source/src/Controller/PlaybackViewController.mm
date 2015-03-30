//
//  PlaybackViewController.m
//  New Focus
//
//  Created by Alex Wiltschko on 7/9/12.
//  Copyright (c) 2012 Datta Lab, Harvard University. All rights reserved.
//

#import "PlaybackViewController.h"

@interface PlaybackViewController() {
    dispatch_source_t callbackTimer; //timer for update of slider/scrubber
    BBFile *aFile;
    BBAudioManager *bbAudioManager;
    BOOL audioPaused;
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


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"numOutputChannels"])
    {
        
        // If the input route changes,
        // remember where we were in the playing audio file, and stop playing that file.
        bbAudioManager = [BBAudioManager bbAudioManager];
        float timeToSeekTo = bbAudioManager.currentFileTime;
        [bbAudioManager pausePlaying];
        
        // Then, make sure that we're either playing through the speaker, or through headphones
        // (never the receiver)
        [self ifNoHeadphonesConfigureAudioToPlayOutOfSpeakers];
        
        
        // And finally, start up the audio file again, and seek to where we were.
        [bbAudioManager startPlaying:bbfile]; // startPlaying: initializes the file and buffers audio
        bbAudioManager.currentFileTime = timeToSeekTo;
        
    }
    
    else if ([keyPath isEqualToString:@"playing"])
    {

        if ([BBAudioManager bbAudioManager].playing == YES) {
            [self.playPauseButton setBackgroundImage:[UIImage imageNamed:@"Pause"] forState:UIControlStateNormal];
        }
        
        else {
            [self.playPauseButton setBackgroundImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];

        }

    }
}

- (void)viewWillAppear:(BOOL)animated
{
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
        [glView removeFromSuperview];
        [glView release];
        glView = nil;
    }
    
    if([[BBAudioManager bbAudioManager] btOn])
    {
        [[BBAudioManager bbAudioManager] closeBluetooth];
    }
    
    
    // our CCGLTouchView being added as a subview
    glView = [[MultichannelCindeGLView alloc] initWithFrame:self.view.frame];

    glView.mode = MultichannelGLViewModePlayback;
	[self.view addSubview:glView];
    [self.view sendSubviewToBack:glView];
    
    // set our view controller's prop that will hold a pointer to our newly created CCGLTouchView
    [self setGLView:glView];

    //[[BBAudioManager bbAudioManager] clearWaveform];
    //
    
    UITapGestureRecognizer *doubleTap = [[[UITapGestureRecognizer alloc] initWithTarget: self action:@selector(autorangeView)] autorelease];
    doubleTap.numberOfTapsRequired = 2;
    [glView addGestureRecognizer:doubleTap];
    
    // Make sure that we're playing out of the right audioroute, and if it changes
    // (e.g., if you unplug the headphones while playing), it just works
    [self ifNoHeadphonesConfigureAudioToPlayOutOfSpeakers];
    [[Novocaine audioManager] addObserver:self forKeyPath:@"numOutputChannels" options:NSKeyValueObservingOptionNew context:NULL];
    [[BBAudioManager bbAudioManager] addObserver:self forKeyPath:@"playing" options:NSKeyValueObservingOptionNew context:NULL];
    
    // Grab the audio file, and start buffering audio from it.
    bbAudioManager = [BBAudioManager bbAudioManager];
    //[[BBAudioManager bbAudioManager] clearWaveform];
    NSURL *theURL = [bbfile fileURL];
    NSLog(@"Playing a file at: %@", theURL);
    [bbAudioManager startPlaying:bbfile]; // startPlaying: initializes the file and buffers audio
    
       // Set the slider to have the bounds of the audio file's duraiton
    timeSlider.minimumValue = 0;
    timeSlider.maximumValue = bbAudioManager.fileDuration;
    // Periodically poll for the current position in the audio file, and update the
    // slider accordingly.
    
    
    callbackTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(callbackTimer, dispatch_walltime(NULL, 0), 0.25*NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(callbackTimer, ^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.timeSlider.isTracking)
                [self.timeSlider setValue:bbAudioManager.currentFileTime];
        });
        
    });
    
    dispatch_resume(callbackTimer);
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [glView setNumberOfChannels: [[BBAudioManager bbAudioManager] sourceNumberOfChannels] samplingRate:[[BBAudioManager bbAudioManager] sourceSamplingRate] andDataSource:self];
    audioPaused = NO;

}


- (void)viewWillDisappear:(BOOL)animated
{

    [[BBAudioManager bbAudioManager] clearWaveform];  
    
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [glView saveSettings:FALSE]; // save non-threshold settings
    
    [glView stopAnimation];
    dispatch_suspend(callbackTimer);
    [[BBAudioManager bbAudioManager] stopPlaying];

    [[Novocaine audioManager] removeObserver:self forKeyPath:@"numOutputChannels"];
    [self restoreAudioOutputRouteToDefault];
    dispatch_suspend(callbackTimer);
    
    [glView removeFromSuperview];
    [glView release];
    glView = nil;
    [super viewWillDisappear:animated];
}


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
    

      /* if(glView)
    {
        [glView stopAnimation];
        [glView removeFromSuperview];
        [glView release];
        glView = nil;
    }
    
    // our CCGLTouchView being added as a subview
    glView = [[MultichannelCindeGLView alloc] initWithFrame:self.view.frame];
    
    //[glView setNumberOfChannels: [[BBAudioManager bbAudioManager] sourceNumberOfChannels] samplingRate:[[BBAudioManager bbAudioManager] sourceSamplingRate] andDataSource:self];
    glView.mode = MultichannelGLViewModePlayback;
	[self.view addSubview:glView];
    [self.view sendSubviewToBack:glView];
    
    // set our view controller's prop that will hold a pointer to our newly created CCGLTouchView
    [self setGLView:glView];*/
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [glView setCurrentBounds:self.view.frame];
}

-(void) autorangeView
{
    [glView autorangeSelectedChannel];
}

- (void)setGLView:(MultichannelCindeGLView *)view
{
    glView = view;
    callbackTimer = nil;
}

#pragma mark - MultichannelGLViewDelegate function
- (float) fetchDataToDisplay:(float *)data numFrames:(UInt32)numFrames whichChannel:(UInt32)whichChannel
{

    //Fetch data and get time of data as precise as posible. Used to sichronize
    //display of waveform and spike marks
    return [[BBAudioManager bbAudioManager] fetchAudio:data numFrames:numFrames whichChannel:whichChannel stride:1];
}

-(float) getCurrentTimeForSinc
{
    return [[BBAudioManager bbAudioManager] getTimeForSpikes];
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


#pragma mark - end of MultichannelGLViewDelegate

- (void)dealloc {
    [timeSlider release];
    [super dealloc];
}



//
// Called when user stop dragging scruber
//
- (void)sliderTouchUpInside:(NSNotification *)notification {
    if(!audioPaused)
    {
        [bbAudioManager setSeeking:NO];
        [bbAudioManager resumePlaying];
    }
}

//
// Called when user start dragging scruber
//
- (void)sliderTouchDown:(NSNotification *)notification {
    [bbAudioManager setSeeking:YES];
    [bbAudioManager pausePlaying];
    audioPaused = YES;
}

//Seek to new place in file
- (IBAction)backBtnClick:(id)sender {
        [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)sliderValueChanged:(id)sender {
    
    bbAudioManager.currentFileTime = (float)self.timeSlider.value;
}

- (IBAction)playPauseButtonPressed:(id)sender
{
    [self togglePlayback];
    audioPaused = !audioPaused;
}

-(void) selectChannel:(int) selectedChannel
{
    [bbAudioManager selectChannel:selectedChannel];
}

- (void)togglePlayback
{

    if (bbAudioManager.playing == false) {
        
        [bbAudioManager resumePlaying];
    }
    else {
        [bbAudioManager pausePlaying];
    }
    
}

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
    NSLog(@"AudioRoute: %@", routeStr);
    
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
    } else {
        NSLog(@"Unknown audio route.");
        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_None;
        AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute,
                                 sizeof (audioRouteOverride),
                                 &audioRouteOverride);
    }
    
}


@end
