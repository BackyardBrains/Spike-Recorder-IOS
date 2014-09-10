//
//  FFTViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/16/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "FFTViewController.h"
#import "BBBTManager.h"

@interface FFTViewController ()

@end

@implementation FFTViewController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    float maxTime = 10.0f;
    [[BBAudioManager bbAudioManager] startDynanimcFFTWithMaxNumberOfSeconds:maxTime];
    
    
    //Config GL view
    if(glView)
    {
        [glView stopAnimation];
        [glView removeFromSuperview];
        [glView release];
        glView = nil;
    }
    glView = [[DynamicFFTCinderGLView alloc] initWithFrame:self.view.frame];
    float baseFreq = 0.5*((float)[[BBAudioManager bbAudioManager] sourceSamplingRate])/((float)[[BBAudioManager bbAudioManager] lengthOfFFTData]);
    [glView setupWithBaseFreq:baseFreq lengthOfFFT:[[BBAudioManager bbAudioManager] lengthOf30HzData] numberOfGraphs:[[BBAudioManager bbAudioManager] lenghtOfFFTGraphBuffer] maxTime:maxTime];
    [[BBAudioManager bbAudioManager] selectChannel:0];
    _channelBtn.hidden = [[BBAudioManager bbAudioManager] sourceNumberOfChannels]<2;
   [self.view addSubview:glView];
   [self.view sendSubviewToBack:glView];
   [glView startAnimation];
    
 /*   
  
  //Old one dimensional FFT graph
  [[BBAudioManager bbAudioManager] startFFT];
    
   //Config GL view
    if(glView)
    {
        [glView stopAnimation];
        [glView removeFromSuperview];
        [glView release];
        glView = nil;
    }
    glView = [[FFTCinderGLView alloc] initWithFrame:self.view.frame];
    float baseFreq = 0.5*((float)[[BBAudioManager bbAudioManager] sourceSamplingRate])/((float)[[BBAudioManager bbAudioManager] lengthOfFFTData]);
    [glView setupWithBaseFreq:baseFreq andLengthOfFFT:[[BBAudioManager bbAudioManager] lengthOfFFTData]];
    [[BBAudioManager bbAudioManager] selectChannel:0];
    _channelBtn.hidden = [[BBAudioManager bbAudioManager] sourceNumberOfChannels]<2;
  
	[self.view addSubview:glView];
    [self.view sendSubviewToBack:glView];
	[glView startAnimation];
    */
    //Bluetooth notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noBTConnection) name:NO_BT_CONNECTION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(btDisconnected) name:BT_DISCONNECTED object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    NSLog(@"Stopping regular view");
    [glView stopAnimation];
    [[BBAudioManager bbAudioManager] stopFFT];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:NO_BT_CONNECTION object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:BT_DISCONNECTED object:nil];
}

- (void)viewDidLoad
{
    
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    NSLog(@"Terminating...");
    [glView stopAnimation];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}




#pragma mark - BT stuff


-(void) noBTConnection
{
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
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Bluetooth connection."
                                                        message:@"Bluetooth device disconnected. Get in range of the device and try to pair with the device in Bluetooth settings again."
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
}

#pragma mark - Channel code

- (IBAction)channelBtnClick:(id)sender {
    SAFE_ARC_RELEASE(popover); popover=nil;
    
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
}

#pragma mark - Destroy view

- (void)dealloc {
    [_channelBtn release];
    [super dealloc];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}


@end
