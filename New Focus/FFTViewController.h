//
//  FFTViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/16/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "CCGLTouchViewController.h"
#import "DynamicFFTCinderGLView.h"
#import "DynamicFFTGraphGLView.h"
#import "BBAudioManager.h"
#import "FPPopoverController.h"
#import "BBChannelSelectionTableViewController.h"

@interface FFTViewController : CCGLTouchViewController <FPPopoverControllerDelegate,BBSelectionTableDelegateProtocol>
{
    DynamicFFTCinderGLView *glView;
    DynamicFFTGraphGLView *oGLView;
    FPPopoverController * popover;
}
@property (retain, nonatomic) IBOutlet UIButton *channelBtn;
- (IBAction)channelBtnClick:(id)sender;

@end
