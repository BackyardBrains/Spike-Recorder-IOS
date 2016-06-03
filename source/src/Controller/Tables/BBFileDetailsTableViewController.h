//
//  BBFileDetailsTableViewController.h
//  Spike Recorder
//
//  Created by Stanislav Mircic on 5/30/16.
//  Copyright © 2016 BackyardBrains. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BBFile.h"

@interface BBFileDetailsTableViewController : UITableViewController

@property (nonatomic, retain) BBFile *bbfile;

- (id)initWithBBFile:(BBFile *)theBBFile;


@end
