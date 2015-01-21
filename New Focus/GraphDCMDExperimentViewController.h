//
//  GraphDCMDExperimentViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/26/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "CCGLTouchViewController.h"
#import "ExperimentDCMDGraphView.h"
#import "BBDCMDTrial.h"


@interface GraphDCMDExperimentViewController : CCGLTouchViewController
{
    ExperimentDCMDGraphView *glView;
}

@property (nonatomic, assign) BBDCMDExperiment * currentExperiment;

@end
