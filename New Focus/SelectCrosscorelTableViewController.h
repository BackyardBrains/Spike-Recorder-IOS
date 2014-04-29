//
//  SelectCrosscorelTableViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/26/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BBFile.h"

@interface SelectCrosscorelTableViewController : UITableViewController

@property (nonatomic, retain) BBFile * file;
- (id)initWithFile:(BBFile *) aFile;

@end
