//
//  FilterSettingsViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 10/29/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NMRangeSlider.h"
@protocol BBFilterConfigDelegate;

@interface FilterSettingsViewController : UIViewController <UITextFieldDelegate,UITextViewDelegate>
@property (retain, nonatomic) IBOutlet UITextField *lowTI;
@property (retain, nonatomic) IBOutlet UITextField *highTI;

@property (nonatomic, assign) id <BBFilterConfigDelegate> masterDelegate;


@property (retain, nonatomic) IBOutlet NMRangeSlider *rangeSlider;

- (IBAction)rangeSliderValueChanged:(id)sender;
- (IBAction)doneButtonClick:(id)sender;

@end

@protocol BBFilterConfigDelegate <NSObject>
-(void) finishedWithConfiguration;
@end
