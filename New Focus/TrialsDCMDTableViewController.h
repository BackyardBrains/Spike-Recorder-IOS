//
//  TrialsDCMDTableViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/10/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BBDCMDExperiment.h"

@interface TrialsDCMDTableViewController : UIViewController<UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate>

@property (retain, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, retain) BBDCMDExperiment * experiment;
@property (nonatomic, retain) NSArray *fileNamesToShare;

@end
