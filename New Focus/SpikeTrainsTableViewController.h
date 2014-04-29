//
//  SpikeTrainsTableViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/25/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BBFile.h"
#define kAUTOCORRELATION 1
#define kISI 2


@interface SpikeTrainsTableViewController : UITableViewController

@property (nonatomic, retain) BBFile * file;
- (id)initWithFile:(BBFile *) aFile andFunction:(int) aFunction;
@end
