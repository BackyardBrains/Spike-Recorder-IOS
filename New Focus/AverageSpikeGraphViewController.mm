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
    [self.navigationController.navigationBar setBarTintColor:[UIColor blackColor]];
    self.navigationController.navigationBar.translucent = NO;
    [self.navigationController.navigationBar setTintColor:[UIColor whiteColor]];
    if([[currentFile allChannels] count] >1)
    {
        if (self.navigationItem.rightBarButtonItem==nil) {
            
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
    //CGRect tempRec = [self.view.frame copy];
    //tempRec
    
    
    
    
    glView = [[AverageSpikeGraphView alloc] initWithFrame:CGRectMake(self.view.frame.origin.x, 0.0f , self.view.frame.size.width, self.view.frame.size.height)];
    
    NSLog(@"\nfW: %f, \nfH: %f, \nfX: %f, \nfY: %f",self.view.frame.size.width, self.view.frame.size.height, self.view.frame.origin.x, self.view.frame.origin.y);
    [glView createGraphForFile:currentFile andChannelIndex:indexOfChannel];
    [self.view addSubview:glView];
    [self.view sendSubviewToBack:glView];
    [glView startAnimation];
    
    
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
    //On these cases is better to specify the arrow direction
    [popover setArrowDirection:FPPopoverArrowDirectionUp];
    [popover presentPopoverFromView:btnView];
}


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


#pragma mark - Rest of view code

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
