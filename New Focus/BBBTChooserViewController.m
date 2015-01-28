//
//  BBBTChooserViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 10/12/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "BBBTChooserViewController.h"

@interface BBBTChooserViewController ()

@end

@implementation BBBTChooserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)dealloc {
    [_deviceTable release];
    [_connectToPairedDevicesBtn release];
    [_infoLbl release];
    [super dealloc];
}
- (IBAction)connectBtnTouch:(id)sender {
}
@end
