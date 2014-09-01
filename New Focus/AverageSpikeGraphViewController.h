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
@interface AverageSpikeGraphViewController : CCGLTouchViewController
{
    AverageSpikeGraphView *glView;
    BBFile * currentFile;
    int indexOfChannel;
}

-(void) calculateGraphForFile:(BBFile * )newFile andChannelIndex:(int) newChannelIndex;

@end