//
//  SpikesAnalysisViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/10/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "SpikesAnalysisViewController.h"
#import "MBProgressHUD.h"
#import "BBChannel.h"
#import "BBChannelSelectionTableViewController.h"

@interface SpikesAnalysisViewController (){
 dispatch_source_t callbackTimer;

 NSInteger pickedChannelIndex;
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
    //put slider at the middle of the file
    [self.timeSlider setValue:[[BBAnalysisManager bbAnalysisManager] fileDuration]*0.5];
    [[BBAnalysisManager bbAnalysisManager] setCurrentFileTime: (float)self.timeSlider.value];
    
    //show buttons for spike trains if we have multiple trains
    [self setupButtons];
    
    [glView loadSettings];
    [glView startAnimation];
}


-(void) setupButtons
{

    self.nextTrainBtn.hidden = [[BBAnalysisManager bbAnalysisManager] numberOfSpikeTrainsOnCurrentChannel]<2;
    self.removeTrainButton.hidden = [[BBAnalysisManager bbAnalysisManager] numberOfSpikeTrainsOnCurrentChannel]<2;
    self.addTrainBtn.hidden = [[BBAnalysisManager bbAnalysisManager] numberOfSpikeTrainsOnCurrentChannel]>2;
    self.channelBtn.hidden = [[[BBAnalysisManager bbAnalysisManager] fileToAnalyze] numberOfChannels]<2;
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

//
// End of selecting/editing save selected spike trains
//
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
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }

}

- (void)dealloc {
    //[triggerHistoryLabel release];
    [doneBtn release];
    [timeSlider release];
    [addTrainBtn release];
    [removeTrainButton release];
    [nextTrainBtn release];
    [_channelBtn release];
    [super dealloc];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (void)didRotate:(NSNotification *)note
{
   /* if(actionSheet)
    {
        [actionSheet dismissWithClickedButtonIndex:0 animated:YES];
        [actionSheet release];
        actionSheet = nil;
        [self performSelector:@selector(channelClick:) withObject:nil afterDelay:1.0];
    }
*/
}


//Add another threshold pair (new spike train)
- (IBAction)addTrainClick:(id)sender {
    [[BBAnalysisManager bbAnalysisManager] addAnotherThresholds];

    self.nextTrainBtn.hidden = NO;
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
        self.nextTrainBtn.hidden = YES;
        self.removeTrainButton.hidden = YES;
    }
    if([[BBAnalysisManager bbAnalysisManager] numberOfSpikeTrainsOnCurrentChannel]<3)
    {
        self.addTrainBtn.hidden = NO;
    }
}

//Move to next spike train
- (IBAction)nextTrainClick:(id)sender {
    [[BBAnalysisManager bbAnalysisManager] moveToNextSpikeTrain];
}

#pragma mark - Selection of channels
//====================================================================================

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
    /*if(sender == transparentPopover)
    {
        popover.alpha = 0.5;
    }
    */

    popover.arrowDirection = FPPopoverArrowDirectionAny;
    [popover presentPopoverFromView:sender];
}


-(NSMutableArray *) getAllChannels
{
    NSMutableArray * allChannelsLabels = [[[NSMutableArray alloc] init] autorelease];
    for(int i=0;i<[[bbfile allChannels] count];i++)
    {
        [allChannelsLabels addObject:[((BBChannel *)[[bbfile allChannels] objectAtIndex:i]) nameOfChannel]];
    }
    return allChannelsLabels;
}


- (void)channelSelected:(NSInteger) channelIndex
{
    [[BBAnalysisManager bbAnalysisManager] setCurrentChannel:channelIndex];
    [self setupButtons];
    [glView channelChanged];
    [popover dismissPopoverAnimated:YES];
}



@end
