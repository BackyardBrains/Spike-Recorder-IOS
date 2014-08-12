//
//  DCMDExperimentViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/7/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "DCMDExperimentViewController.h"
#import "BBAudioManager.h"
#import "MBProgressHUD.h"

#define END_OF_EXPERIMENT_ALERT_TAG 1
#define PAUSE_EXPERIMENT_ALERT_TAG 2

@interface DCMDExperimentViewController ()
{
    
}

@end

@implementation DCMDExperimentViewController

@synthesize experiment = _experiment;

- (void)viewWillAppear:(BOOL)animated
{
    [[self navigationController] setNavigationBarHidden:YES animated:YES];
    [super viewWillAppear:animated];
    NSLog(@"Start experiment View");
    
    //Config GL view
    if(glView)
    {
        [glView stopAnimation];
        [glView removeFromSuperview];
        [glView release];
        glView = nil;
    }
    glView = [[DCMDGLView alloc] initWithFrame:self.view.frame andExperiment:_experiment];
    glView.controllerDelegate = self;
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
}

#pragma mark - GLView delegate

-(void) startSavingExperiment
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Saving...";

    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [_experiment save];
        dispatch_async(dispatch_get_main_queue(), ^{
           
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            [self endOfExperiment];
        });
    });
}

//Delegate method from glView
-(void) endOfExperiment
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"End of experiment" message:@"All data is saved."
                                                   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
    alert.tag = END_OF_EXPERIMENT_ALERT_TAG;
    [alert show];
    [alert release];
}

-(void) userWantsInterupt
{
  
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Experiment paused" message:@"Do you want to quit experiment."
                                                   delegate:self cancelButtonTitle:@"Continue" otherButtonTitles: @"Quit", nil];
    alert.tag = PAUSE_EXPERIMENT_ALERT_TAG;
    [alert show];
    [alert release];
}

-(void) openResultView
{
    [self.masterDelegate endOfExperiment];
}

#pragma mark - Alert view delegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0)
    {
       if(alertView.tag == PAUSE_EXPERIMENT_ALERT_TAG)
       {
           [glView restartCurrentTrial];
       }
       if(alertView.tag == END_OF_EXPERIMENT_ALERT_TAG)
       {
           [self openResultView];
       }
    }
    if (buttonIndex == 1)
    {
        if(alertView.tag == PAUSE_EXPERIMENT_ALERT_TAG)
        {
            [self endOfExperiment];
        }
    }
}

- (void)viewDidLoad
{

    [super viewDidLoad];
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
    [_experiment release];
    [super dealloc];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

@end
