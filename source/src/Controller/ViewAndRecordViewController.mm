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
#import "BBBTManager.h"
#import "BBBTChooserViewController.h"



@interface ViewAndRecordViewController() {
    dispatch_source_t callbackTimer;
    BBFile *aFile;
    dispatch_source_t _timer;
    float recordingTime;
    BOOL rawSelected;
}

@end

@implementation ViewAndRecordViewController
@synthesize slider;
@synthesize recordButton;
@synthesize stimulateButton;
@synthesize stimulatePreferenceButton;
@synthesize bufferStateIndicator;

- (void)viewWillAppear:(BOOL)animated
{
    
    [super viewWillAppear:animated];
    [[BBAudioManager bbAudioManager] startMonitoring];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL enabled = [[defaults valueForKey:@"stimulationEnabled"] boolValue];

    stimulateButton.hidden = !enabled;
    stimulatePreferenceButton.hidden = !enabled;
    if(glView)
    {
        [glView stopAnimation];
        [glView removeFromSuperview];
        [glView release];
        glView = nil;
    }
    glView = [[MultichannelCindeGLView alloc] initWithFrame:self.view.frame];
    [self setGLView:glView];
    glView.mode = MultichannelGLViewModeView;
    [glView setNumberOfChannels: [[BBAudioManager bbAudioManager] sourceNumberOfChannels ] samplingRate:[[BBAudioManager bbAudioManager] sourceSamplingRate] andDataSource:self];
    
	[self.view addSubview:glView];
    [self.view sendSubviewToBack:glView];
	[glView startAnimation];
    
    UITapGestureRecognizer *doubleTap = [[[UITapGestureRecognizer alloc] initWithTarget: self action:@selector(autorangeView)] autorelease];
    doubleTap.numberOfTapsRequired = 2;
    [glView addGestureRecognizer:doubleTap];
    
    // set our view controller's prop that will hold a pointer to our newly created CCGLTouchView
    
    
    if([[BBAudioManager bbAudioManager] btOn])
    {
        glView.channelsConfiguration = [[BBBTManager btManager] activeChannels];
        [self.btButton setImage:[UIImage imageNamed:@"inputicon.png"] forState:UIControlStateNormal];
        [self.bufferStateIndicator setHidden:NO];
    }
    else
    {
        
        //Set all channels to active
        UInt8 configurationOfChannels = 0;
        int tempMask = 1;
        for(int i=0;i<[[BBAudioManager bbAudioManager] sourceNumberOfChannels];i++)
        {
            configurationOfChannels = configurationOfChannels | (tempMask<<i);
        }
        glView.channelsConfiguration = configurationOfChannels;
        
        [self.btButton setImage:[UIImage imageNamed:@"bluetooth.png"] forState:UIControlStateNormal];
        [self.bufferStateIndicator setHidden:YES];
    }

   /* [glView stopAnimation];
    [glView setNumberOfChannels: [[BBAudioManager bbAudioManager] sourceNumberOfChannels] samplingRate:[[BBAudioManager bbAudioManager] sourceSamplingRate] andDataSource:self];
    [glView startAnimation];
    */
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noBTConnection) name:NO_BT_CONNECTION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(btDisconnected) name:BT_DISCONNECTED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(btSlowConnection) name:BT_SLOW_CONNECTION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(foundBTConnection) name:FOUND_BT_CONNECTION object:nil];
    

     [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reSetupScreen) name:RESETUP_SCREEN_NOTIFICATION object:nil];
   // [self detectBluetooth];
    [self.rtSpikeViewButton objectColor:[BYBGLView getSpikeTrainColorWithIndex:4 transparency:1.0f]];
    [self.rtSpikeViewButton changeCurrentState:HANDLE_STATE];
    [self.cancelRTViewButton setHidden:YES];
    [glView setRtConfigurationActive:NO];
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self tapOnCancelRTButton];
    NSLog(@"Stopping regular view");
    [glView saveSettings:FALSE]; // save non-threshold settings
    [glView stopAnimation];
    
    
   /* if([[BBAudioManager bbAudioManager] btOn])
    {
        [self btButtonPressed:nil];
    }*/
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NO_BT_CONNECTION object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:FOUND_BT_CONNECTION object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:BT_DISCONNECTED object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:BT_SLOW_CONNECTION object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:RESETUP_SCREEN_NOTIFICATION object:nil];
}

- (void)viewDidLoad
{
    
    [super viewDidLoad];

    stimulateButton.selected = NO;
    // Listen for going down
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];

    //Add handler for start of RT view
    UITapGestureRecognizer *singleFingerTap =
    [[UITapGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(tapOnRTButton)];
    [self.rtSpikeViewButton addGestureRecognizer:singleFingerTap];
    [singleFingerTap release];
    
    //Add handler for end of RT view
    UITapGestureRecognizer *cancelFingerTap =
    [[UITapGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(tapOnCancelRTButton)];
    [self.cancelRTViewButton addGestureRecognizer:cancelFingerTap];
    [cancelFingerTap release];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    NSLog(@"Terminating...");
    [glView saveSettings:FALSE];
    [glView stopAnimation];
}

- (void)setGLView:(MultichannelCindeGLView *)view
{
    glView = view;
    callbackTimer = nil;
}

-(void) autorangeView
{
    [glView autorangeSelectedChannel];
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


//
// It works with extended channel index
//
- (void) removeChannel:(int) chanelIndex
{

    if([[BBAudioManager bbAudioManager] btOn])
    {
        [self removeBTChannel:chanelIndex];
    }
}


- (void) addChannel:(int) chanelIndex
{
    
    if([[BBAudioManager bbAudioManager] btOn])
    {
        [self addBTChannel:chanelIndex];
    }
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
    [self.view bringSubviewToFront:self.stopButton];
    
    BBAudioManager *bbAudioManager = [BBAudioManager bbAudioManager];
    if (bbAudioManager.recording == false) {
        
        //check if we have non-standard requirements for format and make custom wav
        if([bbAudioManager sourceNumberOfChannels]>2 || [bbAudioManager sourceSamplingRate]!=44100.0f)
        {
            aFile = [[BBFile alloc] initWav];
        }
        else
        {
            //if everything is standard make .m4a file (it has beter compression )
            aFile = [[BBFile alloc] init];
        }
        aFile.numberOfChannels = [bbAudioManager sourceNumberOfChannels];
        aFile.samplingrate = [bbAudioManager sourceSamplingRate];
        [aFile setupChannels];//create name of channels without spike trains
        
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


#pragma mark - BT stuff

/*- (void)detectBluetooth
{
    if(!testBluetoothManager)
    {
        // Put on main queue so we can call UIAlertView from delegate callbacks.
        testBluetoothManager = [[[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()] autorelease];
    }
    [self centralManagerDidUpdateState:testBluetoothManager]; // Show initial state
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSString *stateString = nil;
    switch(testBluetoothManager.state)
    {
        case CBCentralManagerStateResetting: stateString = @"The connection with the system service was momentarily lost, update imminent."; break;
        case CBCentralManagerStateUnsupported: stateString = @"The platform doesn't support Bluetooth Low Energy."; break;
        case CBCentralManagerStateUnauthorized: stateString = @"The app is not authorized to use Bluetooth Low Energy."; break;
        case CBCentralManagerStatePoweredOff: stateString = @"Bluetooth is currently powered off."; break;
        case CBCentralManagerStatePoweredOn: stateString = @"Bluetooth is currently powered on and available to use."; break;
        default: stateString = @"State unknown, update imminent."; break;
    }
    
    NSLog(@"BT state: %@ ************", stateString);
}
*/

#pragma mark - BT connection

-(void) updateBTBufferIndicator
{
    [self.bufferStateIndicator updateBufferState:(((float)[[BBBTManager btManager] numberOfFramesBuffered])/[[BBAudioManager bbAudioManager] sourceSamplingRate])];
}

- (IBAction)btButtonPressed:(id)sender {
    
    //[self openDevicesPopover];
    NSLog(@"BT button pressed");
    
    if([[BBAudioManager bbAudioManager] recording])
    {
        [self stopRecording:nil];
    }
    
    
    if([[BBAudioManager bbAudioManager] btOn])
    {
        if(glView)
        {
            [glView stopAnimation];
            [glView removeFromSuperview];
            [glView release];
            glView = nil;
        }

        [[BBAudioManager bbAudioManager] closeBluetooth];
    }
    else
    {
        [[BBAudioManager bbAudioManager] testBluetoothConnection];
    }
     
}


-(void) reSetupScreen
{
    NSLog(@"Resetup screen");
    if(glView)
    {
        [glView stopAnimation];
        [glView removeFromSuperview];
        [glView release];
        glView = nil;
    }
    
    glView = [[MultichannelCindeGLView alloc] initWithFrame:self.view.frame];

    [glView setNumberOfChannels: [[BBAudioManager bbAudioManager] sourceNumberOfChannels] samplingRate:[[BBAudioManager bbAudioManager] sourceSamplingRate] andDataSource:self];
    glView.mode = MultichannelGLViewModeView;
    [self.view addSubview:glView];
    [self.view sendSubviewToBack:glView];
    
    // set our view controller's prop that will hold a pointer to our newly created CCGLTouchView
    [self setGLView:glView];
    if([[BBAudioManager bbAudioManager] btOn])
    {
        glView.channelsConfiguration = [[BBBTManager btManager] activeChannels];
        [self.btButton setImage:[UIImage imageNamed:@"inputicon.png"] forState:UIControlStateNormal];
        [self.bufferStateIndicator setHidden:NO];
    }
    else
    {
        
        //Set all channels to active
        UInt8 configurationOfChannels = 0;
        int tempMask = 1;
        for(int i=0;i<[[BBAudioManager bbAudioManager] sourceNumberOfChannels];i++)
        {
            configurationOfChannels = configurationOfChannels | (tempMask<<i);
        }
        glView.channelsConfiguration = configurationOfChannels;

        
        [self.btButton setImage:[UIImage imageNamed:@"bluetooth.png"] forState:UIControlStateNormal];
        [self.bufferStateIndicator setHidden:YES];
    }
    stimulateButton.selected = NO;

}


#pragma mark - Devices Popover



//
// ------- THIS IS NOT USED -----------
//
-(void) openDevicesPopover
{
    SAFE_ARC_RELEASE(devicesPopover); devicesPopover=nil;
    
    //the controller we want to present as a popover
    BBBTChooserViewController *deviceChooserVC = [[BBBTChooserViewController alloc] initWithNibName:@"BBBTChooserViewController" bundle:nil];
    //deviceChooserVC.masterDelegate = self;
    
    devicesPopover = [[FPPopoverController alloc] initWithViewController:deviceChooserVC];
    devicesPopover.delegate = self;
    devicesPopover.tint = FPPopoverWhiteTint;
    devicesPopover.border = NO;
    devicesPopover.arrowDirection = FPPopoverNoArrow;
    devicesPopover.title = nil;
    rawSelected = NO;
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        devicesPopover.contentSize = CGSizeMake(300, 450);
    }
    else {
        devicesPopover.contentSize = CGSizeMake(300, 450);
    }
    /*if(sender == transparentPopover)
     {
     popover.alpha = 0.5;
     }
     */
    
    
    [devicesPopover presentPopoverFromPoint: CGPointMake(self.view.center.x, self.view.center.y - devicesPopover.contentSize.height/2)];
    
    [deviceChooserVC release];
    
}





#pragma mark - Channel Popover


-(void) foundBTConnection
{
    NSLog(@"foundConnection view function. Remove the Spinner");
    SAFE_ARC_RELEASE(channelPopover); channelPopover=nil;
    
    int tempSampleRate = [[BBBTManager btManager] maxSampleRateForDevice]/[[BBBTManager btManager] maxNumberOfChannelsForDevice];

    [self.btButton setImage:[UIImage imageNamed:@"inputicon.png"] forState:UIControlStateNormal];
    [self.bufferStateIndicator setHidden:NO];
    
    if(glView)
    {
        [glView stopAnimation];
        [glView removeFromSuperview];
        [glView release];
        glView = nil;
    }
    
    
    
    
    
    //Make configuration for channels so that all available channels are present
    UInt8 configurationOfChannels = 0;
    int tempMask = 1;
    for(int i=0;i<[[BBBTManager btManager] maxNumberOfChannelsForDevice];i++)
    {
        configurationOfChannels = (tempMask<<i) | configurationOfChannels;
    }
    [[BBAudioManager bbAudioManager] switchToBluetoothWithChannels:configurationOfChannels andSampleRate:tempSampleRate];
    
    
    
    
    
    glView = [[MultichannelCindeGLView alloc] initWithFrame:self.view.frame];
    glView.channelsConfiguration = configurationOfChannels;
    [glView setNumberOfChannels: [[BBAudioManager bbAudioManager] sourceNumberOfChannels ] samplingRate:[[BBAudioManager bbAudioManager] sourceSamplingRate] andDataSource:self];
    glView.mode = MultichannelGLViewModeView;
    [self.view addSubview:glView];
    [self.view sendSubviewToBack:glView];

    // set our view controller's prop that will hold a pointer to our newly created CCGLTouchView
    [self setGLView:glView];
}

//
// Count number of channels in configuration
//
-(int) countNumberOfChannels:(int) channelsConfig
{
    int returnNumberOfChannels = 0;
    int tempMask = 1;
    for(int i=0;i<[[BBBTManager btManager] maxNumberOfChannelsForDevice];i++)
    {
        if((channelsConfig & (tempMask<<i))>0)
        {
            returnNumberOfChannels++;
        }
    }
    return returnNumberOfChannels;
}


-(void) removeBTChannel:(int) indexOfChannel
{

    int tempActiveChannels = [[BBBTManager btManager] activeChannels];
    int tempMask = 1;
    tempMask = tempMask<<indexOfChannel;
    tempActiveChannels = tempActiveChannels & (~tempMask);
    float * tempChannelsOffset = [glView getChannelOffsets];
    int tempSampleRate = [[BBBTManager btManager] maxSampleRateForDevice]/[self countNumberOfChannels:tempActiveChannels];
    [self.bufferStateIndicator setHidden:NO];
    [self.btButton setImage:[UIImage imageNamed:@"inputicon.png"] forState:UIControlStateNormal];
    
    if(glView)
    {
        [glView stopAnimation];
        [glView removeFromSuperview];
        [glView release];
        glView = nil;
    }
    [[BBAudioManager bbAudioManager] switchToBluetoothWithChannels:tempActiveChannels andSampleRate:tempSampleRate];
    glView = [[MultichannelCindeGLView alloc] initWithFrame:self.view.frame];
    glView.channelsConfiguration = tempActiveChannels;

    [glView setNumberOfChannels: [[BBAudioManager bbAudioManager] sourceNumberOfChannels ] samplingRate:[[BBAudioManager bbAudioManager] sourceSamplingRate] andDataSource:self];
    [glView setChannelOffsets:tempChannelsOffset];
    glView.mode = MultichannelGLViewModeView;
    [self.view addSubview:glView];
    [self.view sendSubviewToBack:glView];
    
    // set our view controller's prop that will hold a pointer to our newly created CCGLTouchView
    [self setGLView:glView];

}


-(void) addBTChannel:(int) indexOfChannel
{
    int tempActiveChannels = [[BBBTManager btManager] activeChannels];
    int tempMask = 1;
    tempMask = tempMask<<indexOfChannel;
    tempActiveChannels = tempActiveChannels | tempMask;
    
    float * tempChannelsOffset = [glView getChannelOffsets];
    int tempSampleRate = [[BBBTManager btManager] maxSampleRateForDevice]/[self countNumberOfChannels:tempActiveChannels];
    
    [self.bufferStateIndicator setHidden:NO];
    [self.btButton setImage:[UIImage imageNamed:@"inputicon.png"] forState:UIControlStateNormal];
    
    if(glView)
    {
        [glView stopAnimation];
        [glView removeFromSuperview];
        [glView release];
        glView = nil;
    }
    [[BBAudioManager bbAudioManager] switchToBluetoothWithChannels:tempActiveChannels andSampleRate:tempSampleRate];
    glView = [[MultichannelCindeGLView alloc] initWithFrame:self.view.frame];
    glView.channelsConfiguration = tempActiveChannels;

    [glView setNumberOfChannels: [[BBAudioManager bbAudioManager] sourceNumberOfChannels ] samplingRate:[[BBAudioManager bbAudioManager] sourceSamplingRate] andDataSource:self];
    [glView setChannelOffsets:tempChannelsOffset];
    glView.mode = MultichannelGLViewModeView;
    [self.view addSubview:glView];
    [self.view sendSubviewToBack:glView];
    
    // set our view controller's prop that will hold a pointer to our newly created CCGLTouchView
    [self setGLView:glView];

}


- (void)popoverControllerDidDismissPopover:(FPPopoverController *)popoverController
{
    NSLog(@"Dismiss popover");
    if(!rawSelected)
    {
        //stop BT when dismising config popover since it is started before popover was opened
        [[BBAudioManager bbAudioManager] closeBluetooth];
    }
    rawSelected = NO;

}

- (void)rowSelected:(NSInteger) rowIndex
{
    
    NSLog(@"Depricated function called");
   /* rawSelected = YES;
    [channelPopover dismissPopoverAnimated:YES];
    int tempSampleRate = 1000;
    int tempNumOfChannels = 1;
    switch (rowIndex) {
        case 0:
            tempNumOfChannels = 1;
            tempSampleRate = 4000;
            break;
        case 1:
            tempNumOfChannels = 2;
            tempSampleRate = 2000;
            break;
        case 2:
            tempNumOfChannels = 3;
            tempSampleRate = 1333;
            break;
        case 3:
            tempNumOfChannels = 4;
            tempSampleRate = 1000;
            break;
        case 4:
            tempNumOfChannels = 5;
            tempSampleRate = 1000;
            break;
        case 5:
            tempNumOfChannels = 6;
            tempSampleRate = 1000;
            break;
        default:
            break;
    }
    [self.btButton setImage:[UIImage imageNamed:@"inputicon.png"] forState:UIControlStateNormal];

    if(glView)
    {
        [glView stopAnimation];
        [glView removeFromSuperview];
        [glView release];
        glView = nil;
    }
    [[BBAudioManager bbAudioManager] switchToBluetoothWithNumOfChannels:tempNumOfChannels andSampleRate:tempSampleRate];
    glView = [[MultichannelCindeGLView alloc] initWithFrame:self.view.frame];
    
    [glView setNumberOfChannels: [[BBAudioManager bbAudioManager] sourceNumberOfChannels ] samplingRate:[[BBAudioManager bbAudioManager] sourceSamplingRate] andDataSource:self];
    glView.mode = MultichannelGLViewModeView;
	[self.view addSubview:glView];
    [self.view sendSubviewToBack:glView];
	
    // set our view controller's prop that will hold a pointer to our newly created CCGLTouchView
    [self setGLView:glView]; */

}
-(NSMutableArray *) getAllRows
{
    NSMutableArray * allOptionsLabels = [[[NSMutableArray alloc] init] autorelease];

    [allOptionsLabels addObject:@"1 channel (4000Hz)"];
    [allOptionsLabels addObject:@"2 channel (2000Hz)"];
    [allOptionsLabels addObject:@"3 channel (1333Hz)"];
    [allOptionsLabels addObject:@"4 channel (1000Hz)"];
    [allOptionsLabels addObject:@"5 channel (1000Hz)"];
    [allOptionsLabels addObject:@"6 channel (1000Hz)"];
    
    return allOptionsLabels;
}


-(void) finishedWithConfiguration
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


-(void) noBTConnection
{
    [self.bufferStateIndicator setHidden:YES];
    [self.btButton setImage:[UIImage imageNamed:@"bluetooth.png"] forState:UIControlStateNormal];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Bluetooth connection."
                                                    message:@"Please pair with BYB bluetooth device in Bluetooth settings."
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
    [alert release];
}

-(void) btDisconnected
{
    if([[BBAudioManager bbAudioManager] btOn])
    {
        [self.bufferStateIndicator setHidden:YES];
        [self.btButton setImage:[UIImage imageNamed:@"bluetooth.png"] forState:UIControlStateNormal];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Bluetooth connection."
                                                        message:@"Bluetooth device disconnected. Get in range of the device and try to pair with the device in Bluetooth settings again."
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
}

-(void) btSlowConnection
{
    
    if([[BBAudioManager bbAudioManager] btOn])
    {
        [self.bufferStateIndicator setHidden:YES];
        [self.btButton setImage:[UIImage imageNamed:@"bluetooth.png"] forState:UIControlStateNormal];

    }
    
}


#pragma mark - Actions

//
// Start RT processing or just change position of handles
//
-(void) tapOnRTButton
{
    BBAudioManager *bbAudioManager = [BBAudioManager bbAudioManager];
    if([self.rtSpikeViewButton currentStatus] == TICK_MARK_STATE)
    {
        [self.rtSpikeViewButton changeCurrentState:HANDLE_STATE];
        [self.cancelRTViewButton setHidden:YES];
        [glView setRtConfigurationActive:NO];
        [self.rtSpikeViewButton objectColor:[BYBGLView getSpikeTrainColorWithIndex:4 transparency:1.0f]];
    
    }
    else
    {
        if (bbAudioManager.rtSpikeSorting == false) {
            NSLog(@"Start real time spike sorting");
            [bbAudioManager startRTSpikeSorting];
        }
        [glView setRtConfigurationActive:YES];
        [self.cancelRTViewButton setHidden:NO];
        [self.rtSpikeViewButton changeCurrentState:TICK_MARK_STATE];
    }
}


//
// Cancel RT processing
//
-(void) tapOnCancelRTButton
{
     NSLog(@"Stop real time spike sorting");
    [glView setRtConfigurationActive:NO];
     BBAudioManager *bbAudioManager = [BBAudioManager bbAudioManager];
    if([bbAudioManager rtSpikeSorting])
    {
        [bbAudioManager stopRTSpikeSorting];
    }
    [self.rtSpikeViewButton changeCurrentState:HANDLE_STATE];
    [self.cancelRTViewButton setHidden:YES];
    
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
    [_btButton release];
    [_rtSpikeViewButton release];
    [bufferStateIndicator release];
    [_cancelRTViewButton release];
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