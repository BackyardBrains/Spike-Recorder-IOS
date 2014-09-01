//
//  AverageSpikeGraphViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/27/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "AverageSpikeGraphViewController.h"

@interface AverageSpikeGraphViewController ()

@end

@implementation AverageSpikeGraphViewController

-(void) calculateGraphForFile:(BBFile * )newFile andChannelIndex:(int) newChannelIndex
{
    currentFile = newFile;
    indexOfChannel = newChannelIndex;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    //Config GL view
    if(glView)
    {
        [glView stopAnimation];
        [glView removeFromSuperview];
        [glView release];
        glView = nil;
    }
    glView = [[AverageSpikeGraphView alloc] initWithFrame:self.view.frame];
    
    [glView createGraphForFile:currentFile andChannelIndex:indexOfChannel];
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
