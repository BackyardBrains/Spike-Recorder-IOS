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
#import "MBProgressHUD.h"


@interface ViewAndRecordViewController() {
    dispatch_source_t callbackTimer;
    BBFile *aFile;
    dispatch_source_t _timer;
    float recordingTime;
    BOOL rawSelected;
    //CBCentralManager * testBluetoothManager;
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
    // set our view controller's prop that will hold a pointer to our newly created CCGLTouchView
    
    if([[BBAudioManager bbAudioManager] btOn])
    {
        [self.btButton setImage:[UIImage imageNamed:@"inputicon.png"] forState:UIControlStateNormal];
        
    }
    else
    {
        [self.btButton setImage:[UIImage imageNamed:@"bluetooth.png"] forState:UIControlStateNormal];
    }

   /* [glView stopAnimation];
    [glView setNumberOfChannels: [[BBAudioManager bbAudioManager] sourceNumberOfChannels] samplingRate:[[BBAudioManager bbAudioManager] sourceSamplingRate] andDataSource:self];
    [glView startAnimation];
    */
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noBTConnection) name:NO_BT_CONNECTION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(btDisconnected) name:BT_DISCONNECTED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(btSlowConnection) name:BT_SLOW_CONNECTION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(foundBTConnection) name:FOUND_BT_CONNECTION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceChooserClosed) name:BT_WAIT_TO_CONNECT object:nil];
    
   // [self detectBluetooth];
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
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
}

- (void)viewDidLoad
{
    
    [super viewDidLoad];

    stimulateButton.selected = NO;
    // Listen for going down
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
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

#pragma mark - MultichannelGLViewDelegate function
- (float) fetchDataToDisplay:(float *)data numFrames:(UInt32)numFrames whichChannel:(UInt32)whichChannel
{
    
    //Fetch data and get time of data as precise as posible. Used to sichronize
    //display of waveform and spike marks
    return [[BBAudioManager bbAudioManager] fetchAudio:data numFrames:numFrames whichChannel:whichChannel stride:1];
}


-(void) removeChannel:(int) chanelIndex
{

    if([[BBAudioManager bbAudioManager] btOn])
    {
        [self removeBTChannel:chanelIndex];
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
        glView = [[MultichannelCindeGLView alloc] initWithFrame:self.view.frame];
        
        [glView setNumberOfChannels: [[BBAudioManager bbAudioManager] numberOfChannels] samplingRate:[[BBAudioManager bbAudioManager] samplingRate] andDataSource:self];
        glView.mode = MultichannelGLViewModeView;
        [self.view addSubview:glView];
        [self.view sendSubviewToBack:glView];
        
        // set our view controller's prop that will hold a pointer to our newly created CCGLTouchView
        [self setGLView:glView];
        [self.btButton setImage:[UIImage imageNamed:@"bluetooth.png"] forState:UIControlStateNormal];
        stimulateButton.selected = NO;

    }
    else
    {
        [[BBAudioManager bbAudioManager] testBluetoothConnection];
    }
     
}


-(void) deviceChooserClosed
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Configuring...";

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
    dispatch_async(dispatch_get_main_queue(), ^{
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    });
    SAFE_ARC_RELEASE(channelPopover); channelPopover=nil;
    
/*    //the controller we want to present as a popover
    BBChannelSelectionTableViewController *controller = [[BBChannelSelectionTableViewController alloc] initWithStyle:UITableViewStylePlain];
    controller.delegate = self;
    channelPopover = [[FPPopoverController alloc] initWithViewController:controller];
    channelPopover.delegate = self;
    channelPopover.tint = FPPopoverWhiteTint;
    channelPopover.border = NO;
    channelPopover.arrowDirection = FPPopoverNoArrow;
    channelPopover.title = nil;
    rawSelected = NO;
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        channelPopover.contentSize = CGSizeMake(300, 500);
    }
    else {
        channelPopover.contentSize = CGSizeMake(200, 300);
    }

 

    [channelPopover presentPopoverFromPoint: CGPointMake(self.view.center.x, self.view.center.y - channelPopover.contentSize.height/2)];
 */
    
    int tempNumOfChannels = [[BBBTManager btManager] maxNumberOfChannelsForDevice];
    int tempSampleRate = [[BBBTManager btManager] maxSampleRateForDevice]/[[BBBTManager btManager] maxNumberOfChannelsForDevice];

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
    [self setGLView:glView];
    
    

    
    
}


-(void) removeBTChannel:(int) indexOfChannel
{

    int tempNumOfChannels = [[BBAudioManager bbAudioManager] sourceNumberOfChannels]-1;
    int tempSampleRate = [[BBBTManager btManager] maxSampleRateForDevice]/tempNumOfChannels;
    
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
    rawSelected = YES;
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
    [self setGLView:glView];

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
        [self.btButton setImage:[UIImage imageNamed:@"bluetooth.png"] forState:UIControlStateNormal];

    }
    
}


#pragma mark - Actions


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