//
//  TrialActionsViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/10/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BBDCMDTrial.h"
#import "SpikesAnalysisViewController.h"

@protocol TrialActionsDelegate;

@interface TrialActionsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, BBSpikeSortingViewControllerDelegate, UIAlertViewDelegate>
@property (retain, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic,retain) BBDCMDTrial * currentTrial;
@property (nonatomic, assign) id <TrialActionsDelegate> masterDelegate;
@end
@protocol TrialActionsDelegate <NSObject>
-(void) deleteTrial:(BBDCMDTrial *) trialToDelete;
-(void) applySameThresholdsToAllTrials:(BBDCMDTrial *) trialToCopyFrom;
@end