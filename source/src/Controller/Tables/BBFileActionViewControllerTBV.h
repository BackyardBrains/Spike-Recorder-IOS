//
//  BBFileActionViewControllerTBV.h
//  Backyard Brains
//
//  Copyright 2011 Backyard Brains. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "BBFileTableCell.h"
#import "PlaybackViewController.h"
#import "SpikesAnalysisViewController.h"
#import "BBFileDetailsTableViewController.h"


@protocol BBFileActionViewControllerDelegate;

@interface BBFileActionViewControllerTBV : UITableViewController  <UIActionSheetDelegate>
{
    PlaybackViewController * playbackController;
}

@property (nonatomic, assign) id <BBFileActionViewControllerDelegate> delegate;
@property (nonatomic, retain) NSArray *actionOptions;
@property (nonatomic, retain) NSArray *files;

@end

@protocol BBFileActionViewControllerDelegate
    @required
        @property (nonatomic, retain) NSArray *filesSelectedForAction;
        - (void)deleteTheFiles:(NSArray *)files;
@end
