//
//  BBFileDetailViewController 2.h
//  Backyard Brains
//
//  Created by Alex Wiltschko on 5/20/12.
//  Copyright (c) 2012 Backyard Brains. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SensibleTableView/SensibleTableView.h>
#import "BBFile.h"

@interface BBFileDetailViewController : SCTableViewController

@property (nonatomic, retain) BBFile *bbfile;

- (id)initWithBBFile:(BBFile *)theBBFile;

@end
