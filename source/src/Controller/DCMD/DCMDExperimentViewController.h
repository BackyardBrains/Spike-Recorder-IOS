//
//  DCMDExperimentViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/7/14.
//  Copyright (c) BackyardBrains. All rights reserved.
//

#import "CCGLTouchViewController.h"
#import "DCMDGLView.h"
@protocol DCMDExperimentDelegate;

@interface DCMDExperimentViewController : CCGLTouchViewController <DCMDGLDelegate, UIAlertViewDelegate>
{
    DCMDGLView * glView;
}

@property (nonatomic, retain) BBDCMDExperiment *  experiment;
@property (nonatomic, assign) id <DCMDExperimentDelegate> masterDelegate;
-(void) endOfExperiment;
-(void) userWantsInterupt;
-(void) startSavingExperiment;
@end

@protocol DCMDExperimentDelegate <NSObject>
-(void) endOfExperiment;
@end
