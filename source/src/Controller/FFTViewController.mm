//
//  FFTViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/16/14.
//  Copyright (c) 2014 Backyard Brains. All rights reserved.
//

#import "FFTViewController.h"

@interface FFTViewController ()
{
    NSTimer * touchTimer;
    BOOL backButtonActive;
}

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
    glView.masterDelegate = self;
    _channelBtn.hidden = [[BBAudioManager bbAudioManager] sourceNumberOfChannels]<2;
   [self.view addSubview:glView];
   [self.view sendSubviewToBack:glView];
    [self initConstrainsForGLView];
   [glView startAnimation];
    
    //autorange vertical scale on double tap
    UITapGestureRecognizer *doubleTap = [[[UITapGestureRecognizer alloc] initWithTarget: self action:@selector(doubleTapHandler)] autorelease];
    doubleTap.numberOfTapsRequired = 2;
    [glView addGestureRecognizer:doubleTap];
    [self doubleTapHandler];
 
    //Bluetooth notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reSetupScreen) name:RESETUP_SCREEN_NOTIFICATION object:nil];
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
    if(touchTimer)
    {
        [touchTimer invalidate];
        touchTimer = nil;
    }
    [self dismissViewControllerAnimated:YES completion:nil];
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
    [super dealloc];
}

@end
