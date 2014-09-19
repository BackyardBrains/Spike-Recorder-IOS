//
//  ECGViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 9/11/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "ECGViewController.h"
#import "BBBTManager.h"
#import "BBECGAnalysis.h"


@interface ECGViewController ()

@end

@implementation ECGViewController
@synthesize activeHeartImg;

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[BBAudioManager bbAudioManager] startECG];

    self.activeHeartImg.image = [UIImage imageNamed:@"nobeat.png"];
    //Config GL view
    if(glView)
    {
        [glView stopAnimation];
        [glView removeFromSuperview];
        [glView release];
        glView = nil;
    }
    glView = [[ECGGraphView alloc] initWithFrame:self.view.frame];
    glView.masterDelegate = self;
    [glView setupWithBaseFreq:[[BBAudioManager bbAudioManager] sourceSamplingRate]];
    [[BBAudioManager bbAudioManager] selectChannel:0];
    
    _channelButton.hidden = [[BBAudioManager bbAudioManager] sourceNumberOfChannels]<2;
    
    [self.view addSubview:glView];
    [self.view sendSubviewToBack:glView];
    [glView startAnimation];
    
        //Bluetooth notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noBTConnection) name:NO_BT_CONNECTION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(btDisconnected) name:BT_DISCONNECTED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(beatTheHeart) name:HEART_BEAT_NOTIFICATION object:nil];
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
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NO_BT_CONNECTION object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:BT_DISCONNECTED object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:HEART_BEAT_NOTIFICATION object:nil];
}

-(void) changeHeartActive:(BOOL) active
{
    if(active)
    {
        self.activeHeartImg.image = [UIImage imageNamed:@"hasbeat.png"];
    }
    else
    {
        self.activeHeartImg.image = [UIImage imageNamed:@"nobeat.png"];
    }
}

-(void) beatTheHeart
{
    if([[BBAudioManager bbAudioManager] heartBeatPresent])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            
     
            self.activeHeartImg.alpha = 0.6;
            [UIView animateWithDuration:0.2 animations:^(void) {
                self.activeHeartImg.alpha = 1.0;
            }
            completion:^ (BOOL finished)
             {
                 if (finished) {
                     [UIView animateWithDuration:0.2 animations:^(void){
                     // Revert image view to original.
                        self.activeHeartImg.alpha = 0.8;
                        [self.activeHeartImg.layer removeAllAnimations];
                        [self.activeHeartImg setNeedsDisplay];
                      }];
                 }
             }
             
             
             ];
            
        });
    
    }
}


#pragma mark - Channel code

- (IBAction)channelButtonClick:(id)sender {
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


-(NSMutableArray *) getAllRows
{
    NSMutableArray * allChannelsLabels = [[[NSMutableArray alloc] init] autorelease];
    for(int i=0;i<[[BBAudioManager bbAudioManager] sourceNumberOfChannels];i++)
    {
        [allChannelsLabels addObject:[NSString stringWithFormat:@"Channel %d",i+1]];
    }
    return allChannelsLabels;
}


- (void)rowSelected:(NSInteger) rowIndex
{
    [[BBAudioManager bbAudioManager] selectChannel:rowIndex];
    [popover dismissPopoverAnimated:YES];
}

#pragma mark - BT stuff


-(void) noBTConnection
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Bluetooth connection."
                                                    message:@"Please pair with BYB bluetooth device in Bluetooth settings."
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
    [alert release];
}

-(void) btDisconnected
{
    if([[BBAudioManager bbAudioManager] btOn])
    {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Bluetooth connection."
                                                        message:@"Bluetooth device disconnected. Get in range of the device and try to pair with the device in Bluetooth settings again."
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
}


#pragma mark - View code

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [_channelButton release];
    [activeHeartImg release];
    [super dealloc];
}


@end
