//
//  FFTViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/16/14.
//  Copyright (c) 2014 Backyard Brains. All rights reserved.
//

#import "FFTViewController.h"

@interface FFTViewController ()

@end

@implementation FFTViewController

#pragma mark - View management
- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[self navigationController] setNavigationBarHidden:YES animated:NO];
    [[BBAudioManager bbAudioManager] startDynanimcFFT];
    
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
    _channelBtn.hidden = [[BBAudioManager bbAudioManager] sourceNumberOfChannels]<2;
   [self.view addSubview:glView];
   [self.view sendSubviewToBack:glView];
    [self initConstrainsForGLView];
   [glView startAnimation];
    
 
    //Bluetooth notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reSetupScreen) name:RESETUP_SCREEN_NOTIFICATION object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[self navigationController] setNavigationBarHidden:NO animated:NO];
    NSLog(@"Stopping regular view");
    [glView stopAnimation];
    [[BBAudioManager bbAudioManager] stopFFT];
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

#pragma mark - Application management

- (void)applicationWillTerminate:(UIApplication *)application {
    NSLog(@"Terminating...");
    [glView stopAnimation];
}


#pragma mark - Init/Reset

-(void) reSetupScreen
{
   NSLog(@"Resetup screen");
    [[BBAudioManager bbAudioManager] startDynanimcFFT];
    
    //Config GL view
    if(glView)
    {
        [glView stopAnimation];
        [glView removeFromSuperview];
        [glView release];
        glView = nil;
    }
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
    [self dismissViewControllerAnimated:YES completion:nil];
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




@end
