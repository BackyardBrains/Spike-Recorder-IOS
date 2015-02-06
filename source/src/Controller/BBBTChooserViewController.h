//
//  BBBTChooserViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 10/12/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BBBTChooserViewController : UIViewController

@property (retain, nonatomic) IBOutlet UIButton *connectToPairedDevicesBtn;
@property (retain, nonatomic) IBOutlet UILabel *infoLbl;
- (IBAction)connectBtnTouch:(id)sender;
@property (retain, nonatomic) IBOutlet UITableView *deviceTable;
@end
