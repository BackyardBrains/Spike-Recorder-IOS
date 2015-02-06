//
//  BBChannelSelectionTableViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 6/18/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol BBSelectionTableDelegateProtocol;

@interface BBChannelSelectionTableViewController : UITableViewController
@property(nonatomic,assign) id <BBSelectionTableDelegateProtocol> delegate;
@end


@protocol BBSelectionTableDelegateProtocol
@required
- (void)rowSelected:(NSInteger) rowIndex;
-(NSMutableArray *) getAllRows;
@end