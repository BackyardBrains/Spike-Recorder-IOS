//
//  BBChannelSelectionTableViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 6/18/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>
@class SpikesAnalysisViewController;
@interface BBChannelSelectionTableViewController : UITableViewController
@property(nonatomic,assign) SpikesAnalysisViewController *delegate;
@end
