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


@interface SpikesAnalysisViewController (){
 dispatch_source_t callbackTimer;

 NSInteger pickedChannelIndex;
}
@end

@implementation SpikesAnalysisViewController

@synthesize bbfile;
@synthesize timeSlider;
@synthesize addTrainBtn;
@synthesize removeTrainButton;
@synthesize nextBtn;

- (void)viewWillAppear:(BOOL)animated
{
    NSLog(@"Starting Spikes Analysis view");
    [self.navigationController setNavigationBarHidden:YES animated:NO];
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
    
    if(glView!=nil)
    {
        [glView loadSettings];
        [glView startAnimation];
    }
    
    if([[self.bbfile allSpikes] count]==0)
    {
        [self recalculateSpikes];
    }
}

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
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Can't find spikes" message:@"File is too short or it has low sampling rate."
                                                               delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
                [alert show];
                [alert release];
                
                [self resetupGLView];
            });
            
        }
        
    });


}

-(void) resetupGLView
{
    if(glView == nil)
    {
        glView = [[SpikesCinderView alloc] initWithFrame:self.view.frame];
        
        [self.view addSubview:glView];
        [self.view sendSubviewToBack:glView];
        
        // set our view controller's prop that will hold a pointer to our newly created CCGLTouchView
        [self setGLView:glView];
        
    }
    
    [glView loadSettings];
    [glView startAnimation];

}

-(void) setupButtons
{

    self.nextBtn.hidden = [[BBAnalysisManager bbAnalysisManager] numberOfSpikeTrainsOnCurrentChannel]<2;
    self.removeTrainButton.hidden = [[BBAnalysisManager bbAnalysisManager] numberOfSpikeTrainsOnCurrentChannel]<2;
    self.addTrainBtn.hidden = [[BBAnalysisManager bbAnalysisManager] numberOfSpikeTrainsOnCurrentChannel]>2;
    self.channelBtn.hidden = [[[BBAnalysisManager bbAnalysisManager] fileToAnalyze] numberOfChannels]<2;
    [self setNextColor];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self saveAll];
    [glView removeFromSuperview];
    [glView saveSettings];
    [glView stopAnimation];
    [glView release];
    glView = nil;
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [super viewWillDisappear:animated];
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
    
    UITapGestureRecognizer *singleFingerTap =
    [[UITapGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(tapOnNextButton:)];
    [self.nextBtn addGestureRecognizer:singleFingerTap];
    [singleFingerTap release];
    
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
- (IBAction)saveAll {
    [[BBAnalysisManager bbAnalysisManager] solveOverlapForIndex];
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [[BBAnalysisManager bbAnalysisManager] filterSpikes];
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

    [timeSlider release];
    [addTrainBtn release];
    [removeTrainButton release];
    [_channelBtn release];
    [nextBtn release];
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

//Move to next spike train
/*- (IBAction)nextTrainClick:(id)sender {
    [[BBAnalysisManager bbAnalysisManager] moveToNextSpikeTrain];
}*/

//The event handling method
- (void)tapOnNextButton:(UITapGestureRecognizer *)recognizer {
    [[BBAnalysisManager bbAnalysisManager] solveOverlapForIndex];
    [[BBAnalysisManager bbAnalysisManager] moveToNextSpikeTrain];
    [self setNextColor];
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

#pragma mark - Selection of channels Popover
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



- (IBAction)backBtnClick:(id)sender {
        [self.navigationController popViewControllerAnimated:YES];
}
@end
