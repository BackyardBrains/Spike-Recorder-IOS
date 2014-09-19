//
//  ECGViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 9/11/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "CCGLTouchViewController.h"
#import "ECGGraphView.h"
#import "BBAudioManager.h"
#import "FPPopoverController.h"
#import "BBChannelSelectionTableViewController.h"

@interface ECGViewController : CCGLTouchViewController<FPPopoverControllerDelegate,BBSelectionTableDelegateProtocol, HeartBeatDelegate>
{
    ECGGraphView *glView;
    FPPopoverController * popover;
}

@property (retain, nonatomic) IBOutlet UIButton *channelButton;
- (IBAction)channelButtonClick:(id)sender;
@property (retain, nonatomic) IBOutlet UIImageView *activeHeartImg;


@end
