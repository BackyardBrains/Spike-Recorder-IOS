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

#pragma mark - View management

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController.navigationBar setBarTintColor:[UIColor blackColor]];
    self.navigationController.navigationBar.translucent = NO;
    [self.navigationController.navigationBar setTintColor:[UIColor whiteColor]];
    
    //add button that enables user to change channel that is displayed
    if([[currentFile allChannels] count] > 1)
    {
        if (self.navigationItem.rightBarButtonItem==nil)
        {
            UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithTitle:@"Channel" style:UIBarButtonItemStylePlain target:self action:@selector(changeChannel:)];
            self.navigationItem.rightBarButtonItem = rightButton;
        }
    }

    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    if ([self respondsToSelector:@selector(extendedLayoutIncludesOpaqueBars)]) {
        self.extendedLayoutIncludesOpaqueBars = NO;
    }
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    
    //Config GL view
    if(glView)
    {
        [glView stopAnimation];
        [glView removeFromSuperview];
        [glView release];
        glView = nil;
    }

    glView = [[AverageSpikeGraphView alloc] initWithFrame:CGRectMake(self.view.frame.origin.x, 0.0f , self.view.frame.size.width, self.view.frame.size.height)];
    [glView createGraphForFile:currentFile andChannelIndex:indexOfChannel];
    [self.view addSubview:glView];
    [self.view sendSubviewToBack:glView];
    [self initConstrainsForGLView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
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
    [self.navigationController.navigationBar setBarTintColor:nil];
    self.navigationController.navigationBar.translucent = YES;
    [self.navigationController.navigationBar setTintColor:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    
    
    [glView stopAnimation];
    [glView removeFromSuperview];
    [glView release];
    glView = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
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

#pragma mark - Application management

-(void) applicationDidBecomeActive:(UIApplication *)application {
    NSLog(@"\n\nApp will become active - AverageGraph\n\n");
    if(glView)
    {
        [glView startAnimation];
    }
}

-(void) applicationWillResignActive:(UIApplication *)application {
    NSLog(@"\n\nResign active - AverageGraph\n\n");
    [glView stopAnimation];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    NSLog(@"Terminating...");
    [glView stopAnimation];
}


#pragma mark - Init view's data

-(void) calculateGraphForFile:(BBFile * )newFile andChannelIndex:(int) newChannelIndex
{
    currentFile = newFile;
    indexOfChannel = newChannelIndex;
}

#pragma mark - Change channel code

-(void) changeChannel:(id)sender
{
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
    UIBarButtonItem *buttonItem = sender;
    UIView* btnView = [buttonItem valueForKey:@"view"];
    //In these cases is better to specify the arrow direction
    [popover setArrowDirection:FPPopoverArrowDirectionUp];
    [popover presentPopoverFromView:btnView];
}

#pragma mark - BBSelectionTableDelegateProtocol functions

-(NSMutableArray *) getAllRows
{
    NSMutableArray * allChannelsLabels = [[[NSMutableArray alloc] init] autorelease];
    for(int i=0;i<[[currentFile allChannels] count];i++)
    {
        [allChannelsLabels addObject:[((BBChannel *)[[currentFile allChannels] objectAtIndex:i]) nameOfChannel]];
    }
    return allChannelsLabels;
}


- (void)rowSelected:(NSInteger) rowIndex
{
    [glView createGraphForFile:currentFile andChannelIndex:rowIndex];
    [popover dismissPopoverAnimated:YES];
}

#pragma mark - Memory management

- (void)dealloc {
    [super dealloc];
}
@end
