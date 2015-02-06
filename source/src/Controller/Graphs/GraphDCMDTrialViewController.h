//
//  GraphDCMDTrialViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/15/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "CCGLTouchViewController.h"
#import "TrialDCMDGraphView.h"
#import "BBDCMDTrial.h"

@interface GraphDCMDTrialViewController : CCGLTouchViewController
{
    TrialDCMDGraphView *glView;
}

@property (nonatomic, assign) BBDCMDTrial * currentTrial;

@end
