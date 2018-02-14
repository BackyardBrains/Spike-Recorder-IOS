//
//  SpikesAnalysisViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/10/14.
//  Copyright (c) 2014 BackyardBrains. All rights reserved.
//

#import "SpikesAnalysisViewController.h"
#import "MBProgressHUD.h"
#import "BBChannel.h"


@interface SpikesAnalysisViewController (){
}
@end

@implementation SpikesAnalysisViewController

@synthesize bbfile;
@synthesize timeSlider;
@synthesize addTrainBtn;
@synthesize removeTrainButton;
@synthesize nextBtn;


#pragma mark - view management

-(void) viewDidLoad
{
    [super viewDidLoad];
}

-(void) viewDidUnload {
    [super viewDidUnload];
}

-(void) viewWillAppear:(BOOL)animated
{
    NSLog(@"\nStarting Spikes Analysis view\n");
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    [super viewWillAppear:animated];
    // Set the slider to have the bounds of the audio file's duraiton

    [[BBAnalysisManager bbAnalysisManager] prepareFileForSelection:self.bbfile];
    self.timeSlider.continuous = YES;
    self.timeSlider.minimumValue = 0;
    self.timeSlider.maximumValue = [[BBAnalysisManager bbAnalysisManager] fileDuration];
    //put slider at the middle of the file
    [self.timeSlider setValue:[[BBAnalysisManager bbAnalysisManager] fileDuration]*0.5];
    [[BBAnalysisManager bbAnalysisManager] setCurrentFileTime: (float)self.timeSlider.value];
    
    //show buttons for spike trains if we have multiple trains
    [self setupButtons];
    
    UITapGestureRecognizer *singleFingerTap =
    [[UITapGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(tapOnNextButton:)];
    [self.nextBtn addGestureRecognizer:singleFingerTap];
    [singleFingerTap release];
    
    //recalculateSpikes must be before glView creation
    //bacause glView counts that BBAnalysisManager will initialize some arrays
    if([[self.bbfile allSpikes] count]==0)
    {
        [self recalculateSpikes];
    }
    
    if(glView==nil)
    {
        glView = [[SpikesCinderView alloc] initWithFrame:self.view.frame];
        [self.view addSubview:glView];
        [self.view sendSubviewToBack:glView];
        [self setGLView:glView];
        [self initConstrainsForGLView];
    }
    [glView loadSettings];
    [glView startAnimation];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}


-(void) viewWillDisappear:(BOOL)animated
{
    NSLog(@"\n\nviewWillDisappear - SpikesAnalysis view\n");
    [self saveAll];
    [glView removeFromSuperview];
    [glView saveSettings];
    [glView stopAnimation];
    [glView release];
    glView = nil;
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
    
    [super viewWillDisappear:animated];
}

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

#pragma mark - Application management

-(void) applicationDidBecomeActive:(UIApplication *)application {
    NSLog(@"\n\nApp will become active - SpikeAnalysis\n\n");
    if(glView)
    {
        [glView startAnimation];
    }
}

-(void) applicationWillResignActive:(UIApplication *)application {
    NSLog(@"\n\nResign active - SpikeAnalysis\n\n");
    [glView stopAnimation];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    NSLog(@"Terminating from Spikes Analysis app...");
    [glView saveSettings];
    [glView stopAnimation];
}


#pragma mark - Init/Reset view

-(void) resetupGLView
{
    if(glView == nil)
    {
        glView = [[SpikesCinderView alloc] initWithFrame:self.view.frame];
        
        [self.view addSubview:glView];
        [self.view sendSubviewToBack:glView];
        
        // set our view controller's prop that will hold a pointer to our newly created CCGLTouchView
        [self setGLView:glView];
        [self initConstrainsForGLView];
    }
    
    [glView loadSettings];
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

-(void) setupButtons
{

    self.nextBtn.hidden = [[BBAnalysisManager bbAnalysisManager] numberOfSpikeTrainsOnCurrentChannel]<2;
    self.removeTrainButton.hidden = [[BBAnalysisManager bbAnalysisManager] numberOfSpikeTrainsOnCurrentChannel]<2;
    self.addTrainBtn.hidden = [[BBAnalysisManager bbAnalysisManager] numberOfSpikeTrainsOnCurrentChannel]>2;
    self.channelBtn.hidden = [[[BBAnalysisManager bbAnalysisManager] fileToAnalyze] numberOfChannels]<2;
    [self setNextColor];
}

- (void)setGLView:(SpikesCinderView *)view
{
    glView = view;
}

#pragma mark - UI Handlers

- (IBAction)timeValueChanged:(id)sender {
    [[BBAnalysisManager bbAnalysisManager] setCurrentFileTime: (float)self.timeSlider.value];
}

//Add another threshold pair (new spike train)
- (IBAction)addTrainClick:(id)sender {
    [[BBAnalysisManager bbAnalysisManager] solveOverlapForIndex];
    [[BBAnalysisManager bbAnalysisManager] addAnotherThresholds];

    self.nextBtn.hidden = NO;
    self.removeTrainButton.hidden = NO;
    if([[BBAnalysisManager bbAnalysisManager] numberOfSpikeTrainsOnCurrentChannel]>2)
    {
        self.addTrainBtn.hidden = YES;
    }
}

//Add threshold pair (spike train)
- (IBAction)removeTrainClick:(id)sender {
    [[BBAnalysisManager bbAnalysisManager] removeSelectedThresholds];
    if([[BBAnalysisManager bbAnalysisManager] numberOfSpikeTrainsOnCurrentChannel]<2)
    {
        self.nextBtn.hidden = YES;
        self.removeTrainButton.hidden = YES;
    }
    if([[BBAnalysisManager bbAnalysisManager] numberOfSpikeTrainsOnCurrentChannel]<3)
    {
        self.addTrainBtn.hidden = NO;
    }
}

- (void)tapOnNextButton:(UITapGestureRecognizer *)recognizer {
    [[BBAnalysisManager bbAnalysisManager] solveOverlapForIndex];
    [[BBAnalysisManager bbAnalysisManager] moveToNextSpikeTrain];
    [self setNextColor];
}

- (IBAction)backBtnClick:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Selection of channels Popover

- (IBAction)channelClick:(id)sender {
    
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

#pragma mark - BBSelectionTableDelegateProtocol

-(NSMutableArray *) getAllRows
{
    NSMutableArray * allChannelsLabels = [[[NSMutableArray alloc] init] autorelease];
    for(int i=0;i<[[bbfile allChannels] count];i++)
    {
        [allChannelsLabels addObject:[((BBChannel *)[[bbfile allChannels] objectAtIndex:i]) nameOfChannel]];
    }
    return allChannelsLabels;
}


- (void)rowSelected:(NSInteger) rowIndex
{
    [[BBAnalysisManager bbAnalysisManager] setCurrentChannel:rowIndex];
    [self setupButtons];
    [glView channelChanged];
    [popover dismissPopoverAnimated:YES];
}


#pragma mark - Helper functions

-(void) recalculateSpikes
{
    BBFile * fileToAnalyze = self.bbfile;
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Analyzing Spikes";
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        if([[BBAnalysisManager bbAnalysisManager] findSpikes:fileToAnalyze] != -1)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [MBProgressHUD hideHUDForView:self.view animated:YES];
                [self resetupGLView];
            });
        }
        else
        {
            //we have error on spike searching
            dispatch_async(dispatch_get_main_queue(), ^{
                [MBProgressHUD hideHUDForView:self.view animated:YES];
                UIAlertController *alertView = [UIAlertController alertControllerWithTitle:@"Can't find spikes" message:@"File is too short or it has low sampling rate." preferredStyle:UIAlertControllerStyleAlert];
                [alertView addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action)
                                      {
                                          // OK button tappped. Do nothing
                                          [self dismissViewControllerAnimated:YES completion:^{
                                          }];
                                      }]];
                // Present action sheet.
                [self presentViewController:alertView animated:YES completion:nil];
                
                
                [self resetupGLView];
            });
        }
    });//dispatch_async dispatch_get_global_queue
}

//
// End of selecting/editing save selected spike trains
//
-(void) saveAll {
    [[BBAnalysisManager bbAnalysisManager] solveOverlapForIndex];
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [[BBAnalysisManager bbAnalysisManager] filterSpikes];
    });
}

-(void) setNextColor
{
    int nextIndex = [[BBAnalysisManager bbAnalysisManager] currentSpikeTrain]+1;
    int numberOfSpikeTrains = [[BBAnalysisManager bbAnalysisManager] numberOfSpikeTrainsOnCurrentChannel];
    if(nextIndex >= numberOfSpikeTrains)
    {
        nextIndex = 0;
    }
    [self.nextBtn nextColor:[BYBGLView getSpikeTrainColorWithIndex:nextIndex transparency:1.0f]];
}


#pragma mark - Memory management

- (void)dealloc {
    //[triggerHistoryLabel release];
    
    [timeSlider release];
    [addTrainBtn release];
    [removeTrainButton release];
    [_channelBtn release];
    [nextBtn release];
    [bbfile release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning {
    NSLog(@"\n\n!Memory Warning! Spike Analysis\n\n");
    // Releases the view if it doesn't have a superview
    [super didReceiveMemoryWarning];
}


@end
