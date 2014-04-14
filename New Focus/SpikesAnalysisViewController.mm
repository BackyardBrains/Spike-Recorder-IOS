//
//  SpikesAnalysisViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/10/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "SpikesAnalysisViewController.h"

@interface SpikesAnalysisViewController (){
 dispatch_source_t callbackTimer;
}
@end

@implementation SpikesAnalysisViewController

@synthesize doneBtn;
@synthesize bbfile;
@synthesize timeSlider;

- (void)viewWillAppear:(BOOL)animated
{
    NSLog(@"Starting Spikes Analysis view");
    [super viewWillAppear:animated];
    // Set the slider to have the bounds of the audio file's duraiton

    [[BBAnalysisManager bbAnalysisManager] prepareFileForSelection:self.bbfile];
    self.timeSlider.minimumValue = 0;
    self.timeSlider.maximumValue = [[BBAnalysisManager bbAnalysisManager] fileDuration];
    [self.timeSlider setValue:[[BBAnalysisManager bbAnalysisManager] currentFileTime]];
    [glView loadSettings];
    [glView startAnimation];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [glView saveSettings];
    [glView stopAnimation];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.timeSlider.continuous = YES;
    
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
    [super dealloc];
}

- (void)viewDidUnload {
    //[triggerHistoryLabel release];
    //triggerHistoryLabel = nil;
    //[self setTriggerHistoryLabel:nil];
    [super viewDidUnload];
}


@end
