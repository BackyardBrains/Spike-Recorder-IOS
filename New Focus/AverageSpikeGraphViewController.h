//
//  AverageSpikeGraphViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/27/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "CCGLTouchViewController.h"
#import "AverageSpikeGraphView.h"
#import "BBFile.h"
#import "FPPopoverController.h"
#import "BBChannelSelectionTableViewController.h"

@interface AverageSpikeGraphViewController : CCGLTouchViewController <FPPopoverControllerDelegate,BBSelectionTableDelegateProtocol, UIBarPositioningDelegate >
{
    AverageSpikeGraphView *glView;
    BBFile * currentFile;
    int indexOfChannel;
    FPPopoverController * popover;
}

-(void) calculateGraphForFile:(BBFile * )newFile andChannelIndex:(int) newChannelIndex;

@end