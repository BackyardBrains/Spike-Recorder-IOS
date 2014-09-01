//
//  GraphDCMDExperimentViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/26/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "GraphDCMDExperimentViewController.h"

@interface GraphDCMDExperimentViewController ()

@end

@implementation GraphDCMDExperimentViewController

@synthesize currentExperiment;
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    //Config GL view
    if(glView)
    {
        [glView stopAnimation];
        [glView removeFromSuperview];
        [glView release];
        glView = nil;
    }
    glView = [[ExperimentDCMDGraphView alloc] initWithFrame:self.view.frame];
    
    [glView createGraphForExperiment:self.currentExperiment];
    [self.view addSubview:glView];
    [self.view sendSubviewToBack:glView];
    [glView startAnimation];
    
    
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
    [glView removeFromSuperview];
    [glView release];
    glView = nil;}

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





#pragma mark - Destroy view

- (void)dealloc {
    [super dealloc];
}

@end
