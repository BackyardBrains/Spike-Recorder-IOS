//
//  SpikesAnalysisViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/10/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "SpikesAnalysisViewController.h"
#import "MBProgressHUD.h"

@interface SpikesAnalysisViewController (){
 dispatch_source_t callbackTimer;
}
@end

@implementation SpikesAnalysisViewController

@synthesize doneBtn;
@synthesize bbfile;
@synthesize timeSlider;
@synthesize addTrainBtn;
@synthesize removeTrainButton;
@synthesize nextTrainBtn;

- (void)viewWillAppear:(BOOL)animated
{
    NSLog(@"Starting Spikes Analysis view");
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    [super viewWillAppear:animated];
    // Set the slider to have the bounds of the audio file's duraiton

    [[BBAnalysisManager bbAnalysisManager] prepareFileForSelection:self.bbfile];
    self.timeSlider.minimumValue = 0;
    self.timeSlider.maximumValue = [[BBAnalysisManager bbAnalysisManager] fileDuration];
    [self.timeSlider setValue:[[BBAnalysisManager bbAnalysisManager] fileDuration]*0.5];
    [[BBAnalysisManager bbAnalysisManager] setCurrentFileTime: (float)self.timeSlider.value];
    
    if([[BBAnalysisManager bbAnalysisManager] numberOfSpikeTrains]<2)
    {
        self.nextTrainBtn.hidden = YES;
        self.removeTrainButton.hidden = YES;
    }
    
    [glView loadSettings];
    [glView startAnimation];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [glView saveSettings];
    [glView stopAnimation];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.timeSlider.continuous = YES;
    [[BBAnalysisManager bbAnalysisManager] prepareFileForSelection:self.bbfile];

    // our CCGLTouchView being added as a subview
    glView = [[SpikesCinderView alloc] initWithFrame:self.view.frame];
    
	[self.view addSubview:glView];
    [self.view sendSubviewToBack:glView];
	
    // set our view controller's prop that will hold a pointer to our newly created CCGLTouchView
    [self setGLView:glView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
    
}

- (void)applicationWillTerminate:(UIApplication *)application {
    NSLog(@"Terminating from Spikes Analysis app...");
    [glView saveSettings];
    [glView stopAnimation];
}


- (void)setGLView:(SpikesCinderView *)view
{
    glView = view;
    callbackTimer = nil;
}

- (IBAction)doneClickAction:(id)sender {
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Saving selection";
    doneBtn.enabled = NO;
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [[BBAnalysisManager bbAnalysisManager] filterSpikes];
        dispatch_async(dispatch_get_main_queue(), ^{
            doneBtn.enabled = YES;
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            [self.navigationController popViewControllerAnimated:YES];
        });
    });
}
- (IBAction)timeValueChanged:(id)sender {
    [[BBAnalysisManager bbAnalysisManager] setCurrentFileTime: (float)self.timeSlider.value];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

- (void)dealloc {
    //[triggerHistoryLabel release];
    [doneBtn release];
    [timeSlider release];
    [addTrainBtn release];
    [removeTrainButton release];
    [nextTrainBtn release];
    [super dealloc];
}

- (void)viewDidUnload {
    //[triggerHistoryLabel release];
    //triggerHistoryLabel = nil;
    //[self setTriggerHistoryLabel:nil];
    [super viewDidUnload];
}


- (IBAction)addTrainClick:(id)sender {
    [[BBAnalysisManager bbAnalysisManager] addAnotherThresholds];

    self.nextTrainBtn.hidden = NO;
    self.removeTrainButton.hidden = NO;
    
}

- (IBAction)removeTrainClick:(id)sender {
    [[BBAnalysisManager bbAnalysisManager] removeSelectedThresholds];
    if([[BBAnalysisManager bbAnalysisManager] numberOfSpikeTrains]<2)
    {
        self.nextTrainBtn.hidden = YES;
        self.removeTrainButton.hidden = YES;
    }
}

- (IBAction)nextTrainClick:(id)sender {
    [[BBAnalysisManager bbAnalysisManager] moveToNextSpikeTrain];
}
@end
