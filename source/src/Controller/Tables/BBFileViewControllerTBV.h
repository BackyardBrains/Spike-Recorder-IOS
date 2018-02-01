//
//  BBFileTableViewControllerTBV.h
//  Backyard Brains
//  Copyright 2011 Backyard Brains. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "BBFile.h"
#import "BBFileTableCell.h"
#import "BBFileActionViewControllerTBV.h"

@class BBFileViewControllerTBV;

@interface BBFileViewControllerTBV: UITableViewController <UIActionSheetDelegate, BBFileActionViewControllerDelegate>
{
    NSMutableArray* filePathsOnDropBox;
}

@property (nonatomic, retain) NSMutableArray *allFiles;
@property (nonatomic, retain) UIButton *dbStatusBar;

@end
