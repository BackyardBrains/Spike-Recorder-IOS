//
//  ExperimentSetupViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/6/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "ExperimentSetupViewController.h"
#import "BBDCMDTrial.h"
#import "DCMDExperimentViewController.h"
@interface ExperimentSetupViewController ()
{
    UITextField * activeField;
    UITextView * activeView;
}
@end

@implementation ExperimentSetupViewController

@synthesize experiment = _experiment;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        //self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.scroller setScrollEnabled:YES];
    [self.scroller setContentSize:CGSizeMake(self.view.frame.size.width, 930)];
    self.commentTB.layer.borderWidth = 0.5f;
    self.commentTB.layer.borderColor = [[UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:0.15] CGColor];
    //self.commentTB.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    self.commentTB.layer.cornerRadius = 8;
    activeView = nil;
    activeField = nil;
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(makeKeyboardDisapear)];
    // prevents the scroll view from swallowing up the touch event of child buttons
    tapGesture.cancelsTouchesInView = NO;
    [self.scroller addGestureRecognizer:tapGesture];
    [tapGesture release];
    
    self.nameTB.delegate = self;
    self.commentTB.delegate = self;
    self.distanceTB.delegate = self;
    self.velocityTB.delegate = self;
    self.sizeTB.delegate = self;
    self.delayTB.delegate = self;
    self.numOfTrialsTB.delegate = self;
    
    
    [self registerForKeyboardNotifications];
    [self setDataFromExperimentToForm];
    
    self.title = @"Experiment Setup";
}

#pragma mark - Experiment code

- (IBAction)doneClick:(id)sender {
    [self getDataFromFormToExperiment];
    [self createTrialsForExperiment];
    [_experiment save];
    [self.masterDelegate endOfSetup];
    
   
}

//
// Create details of all trials in experiment
//
-(void) createTrialsForExperiment
{
    [_experiment.trials removeAllObjects];
    int cumulNumOfDifferentTrials = [_experiment.velocities count]*[_experiment.sizes count];
    int speedIndex;
    int sizeIndex;
    for(int i=0;i<cumulNumOfDifferentTrials;i++)
    {
        for(int k=0;k<_experiment.numberOfTrialsPerPair;k++)
        {
            BBDCMDTrial * newTrial = [[BBDCMDTrial alloc] initWithSize:0.0f velocity:0.0f andDistance:0.0f];
            
            speedIndex = i%[_experiment.velocities count];
            sizeIndex = i/[_experiment.velocities count];
            newTrial.velocity = [(NSNumber *)[_experiment.velocities objectAtIndex:speedIndex] floatValue];
            newTrial.size = [(NSNumber *)[_experiment.sizes objectAtIndex:sizeIndex] floatValue];
            newTrial.distance = _experiment.distance;
            //??? TimeOfImpact  ???
            
            [_experiment.trials addObject:newTrial];
            [newTrial release];
        }
    }
}


-(void) setDataFromExperimentToForm
{
    self.nameTB.text = _experiment.name;
    self.commentTB.text = _experiment.comment;
    self.distanceTB.text = [NSString stringWithFormat:@"%f",_experiment.distance];
    
    NSMutableString * velocityString = [[NSMutableString alloc] initWithString:@""];
    for(int i=0;i<[_experiment.velocities count];i++)
    {
        [velocityString appendFormat:@"%f",[((NSNumber *)[_experiment.velocities objectAtIndex:i]) floatValue]];
        if(i!=[_experiment.velocities count]-1)
        {
            [velocityString appendString:@", "];
        }
    }
    
    self.velocityTB.text = velocityString;
    [velocityString release];
    
    
    NSMutableString * sizeString = [[NSMutableString alloc] initWithString:@""];
    for(int i=0;i<[_experiment.sizes count];i++)
    {
        [sizeString appendFormat:@"%f",[((NSNumber *)[_experiment.sizes objectAtIndex:i]) floatValue]];
        if(i!=[_experiment.sizes count]-1)
        {
            [velocityString appendString:@", "];
        }
    }
    
    self.sizeTB.text = sizeString;
    [sizeString release];

    self.delayTB.text = [NSString stringWithFormat:@"%f",_experiment.delayBetweenTrials];
    self.numOfTrialsTB.text = [NSString stringWithFormat:@"%d",_experiment.numberOfTrialsPerPair];
    int cumulNumOfTrials = [_experiment.velocities count]*[_experiment.sizes count]*_experiment.numberOfTrialsPerPair;
        
    _cumulativeNumberOfTrialsLBL.text = [NSString stringWithFormat:@"Cummulative number of trials: %d (aprox. time %dmin)", cumulNumOfTrials, (int)(((float)(_experiment.delayBetweenTrials*cumulNumOfTrials))/60.0f)];
}

-(void) getDataFromFormToExperiment
{
    _experiment.name  = [self.nameTB.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if([_experiment.name isEqualToString:@""])
    {
        _experiment.name = [NSString stringWithFormat:@"Experiment %d", [[BBDCMDExperiment allObjects] count]+1];
    }
    
    _experiment.comment  = [self.commentTB.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    _experiment.distance = [self.distanceTB.text floatValue];
    _experiment.delayBetweenTrials = [self.delayTB.text floatValue];
    _experiment.numberOfTrialsPerPair = [self.numOfTrialsTB.text intValue];
    
    NSArray *items = [self.sizeTB.text componentsSeparatedByString:@","];
    [_experiment.sizes removeAllObjects];
    for(int i=0;i<[items count];i++)
    {
        [_experiment.sizes addObject:[NSNumber numberWithFloat:[(NSString *)[items objectAtIndex:i] floatValue]]];
    }
    
    items = [self.velocityTB.text componentsSeparatedByString:@","];
    [_experiment.velocities removeAllObjects];
    for(int i=0;i<[items count];i++)
    {
        [_experiment.velocities addObject:[NSNumber numberWithFloat:[(NSString *)[items objectAtIndex:i] floatValue]]];
    }
    
     int cumulNumOfTrials = [_experiment.velocities count]*[_experiment.sizes count]*_experiment.numberOfTrialsPerPair;
     _cumulativeNumberOfTrialsLBL.text = [NSString stringWithFormat:@"Cummulative number of trials: %d (aprox. time %dmin)", cumulNumOfTrials, (int)(((float)(_experiment.delayBetweenTrials*cumulNumOfTrials))/60.0f)];

}


#pragma mark - Keyboard stuff

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    activeField = textField;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    activeField = nil;
    [textField resignFirstResponder];
    [self getDataFromFormToExperiment];
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    activeView = textView;
}


- (void)textViewDidEndEditing:(UITextView *)textView
{
    activeView = nil;
    [textView resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}



// Call this method somewhere in your view controller setup code.
- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
}

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
   // CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    CGRect rawKeyboardRect = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    CGRect kbSize = [self.view.window convertRect:rawKeyboardRect toView:self.view.window.rootViewController.view];
    
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.size.height, 0.0);
    self.scroller.contentInset = contentInsets;
    self.scroller.scrollIndicatorInsets = contentInsets;
    
    // If active text field is hidden by keyboard, scroll it so it's visible
    // Your app might not need or want this behavior.
    CGRect aRect = self.view.frame;
    aRect.size.height -= kbSize.size.height;
    if (!CGRectContainsPoint(aRect, activeField.frame.origin) ) {
        [self.scroller scrollRectToVisible:activeField.frame animated:YES];
    }
    if (!CGRectContainsPoint(aRect, activeView.frame.origin) ) {
        [self.scroller scrollRectToVisible:activeField.frame animated:YES];
    }
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    self.scroller.contentInset = contentInsets;
    self.scroller.scrollIndicatorInsets = contentInsets;
}


-(void) makeKeyboardDisapear
{
    [self.nameTB resignFirstResponder];
    [self.commentTB resignFirstResponder];
    [self.velocityTB resignFirstResponder];
    [self.sizeTB resignFirstResponder];
    [self.distanceTB resignFirstResponder];
    [self.delayTB resignFirstResponder];
    [self.numOfTrialsTB resignFirstResponder];
}


#pragma mark - Memory stuf

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    
    [_scroller release];
    [_nameTB release];
    [_commentTB release];
    [_velocityTB release];
    [_sizeTB release];
    [_numOfTrialsTB release];
    [_distanceTB release];
    [_doneBtn release];
    [_cumulativeNumberOfTrialsLBL release];
    [_delayTB release];
    [_experiment release];
    [super dealloc];
}

@end
