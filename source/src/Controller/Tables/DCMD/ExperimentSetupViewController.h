//
//  ExperimentSetupViewController.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/6/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "BBDCMDExperiment.h"


@protocol  DCMDSetupExperimentDelegate;

@interface ExperimentSetupViewController : UIViewController <UITextFieldDelegate,UITextViewDelegate>
@property (retain, nonatomic) IBOutlet UIScrollView *scroller;
@property (retain, nonatomic) IBOutlet UITextField *nameTB;
@property (retain, nonatomic) IBOutlet UITextView *commentTB;
@property (retain, nonatomic) IBOutlet UITextField *velocityTB;
@property (retain, nonatomic) IBOutlet UITextField *sizeTB;
@property (retain, nonatomic) IBOutlet UITextField *numOfTrialsTB;
@property (retain, nonatomic) IBOutlet UITextField *distanceTB;
@property (retain, nonatomic) IBOutlet UIButton *doneBtn;
@property (retain, nonatomic) IBOutlet UILabel *cumulativeNumberOfTrialsLBL;

@property (retain, nonatomic) IBOutlet UITextField *delayTB;


@property (retain, nonatomic) IBOutlet UITextField *colorTB;



@property (retain, nonatomic) BBDCMDExperiment * experiment;

@property (nonatomic, assign) id <DCMDSetupExperimentDelegate> masterDelegate;

- (IBAction)doneClick:(id)sender;



@end

@protocol DCMDSetupExperimentDelegate <NSObject>
-(void) endOfSetup;
@end
