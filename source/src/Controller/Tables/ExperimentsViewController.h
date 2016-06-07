//
//  ExperimentsViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/5/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BBDCMDExperiment.h"
#import "ExperimentSetupViewController.h"
#import "DCMDExperimentViewController.h"
#import "TrialsDCMDTableViewController.h"

@interface ExperimentsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, DCMDSetupExperimentDelegate, DCMDExperimentDelegate>
@property (retain, nonatomic)  UITableView *expTableView;


@property (nonatomic,retain) NSMutableArray* allExperiments;
@property (nonatomic, retain) BBDCMDExperiment * myNewExperiment;
@end
