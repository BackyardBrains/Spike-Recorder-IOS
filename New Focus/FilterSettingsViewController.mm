//
//  FilterSettingsViewController.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 10/29/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "FilterSettingsViewController.h"
#import "BBAudioManager.h"
@interface FilterSettingsViewController ()
{
    UITextField * activeField;
}

@end

@implementation FilterSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.lowSlider.continuous = YES;
    self.highSlider.continuous = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) viewWillAppear:(BOOL)animated
{
    
    if (self.navigationItem.rightBarButtonItem==nil)
    {
        
        // create an array for the buttons
        NSMutableArray* buttons = [[NSMutableArray alloc] initWithCapacity:2];
        
        // create a standard save button
        UIBarButtonItem *doneButton = [[UIBarButtonItem alloc]
                                       initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                       target:self
                                       action:@selector(applyFilter:)];
        doneButton.style = UIBarButtonItemStyleBordered;
        [buttons addObject:doneButton];
        [doneButton release];
        
        // place the toolbar into the navigation bar
        self.navigationItem.rightBarButtonItems = buttons;
        [buttons release];
        
    }
    
    [self loadSettings];
    
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self saveSettings];
}

-(void) applyFilter:(id) sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)loadSettings
{
    
    NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    float lowFilterValue = [[defaults valueForKey:@"lowFilterFreq"] floatValue];
    
    // Set the slider to have the bounds of the audio file's duraiton
    self.lowSlider.minimumValue = 0;
    self.lowSlider.maximumValue = [[BBAudioManager bbAudioManager] sourceSamplingRate];

    if(lowFilterValue<0)
    {
        lowFilterValue = 0.0f;
    }else if(lowFilterValue>self.lowSlider.maximumValue)
    {
        lowFilterValue = self.lowSlider.maximumValue;
    }
    
    [self.lowSlider setValue:lowFilterValue];
    
    self.lowTI.text = [NSString stringWithFormat:@"%d",(int)lowFilterValue];
    
    float highFilterValue = [[defaults valueForKey:@"highFilterFreq"] floatValue];
    self.highSlider.minimumValue = 0;
    self.highSlider.maximumValue = [[BBAudioManager bbAudioManager] sourceSamplingRate];
    
    if(highFilterValue<0)
    {
        highFilterValue = 0.0f;
    }else if(highFilterValue>self.lowSlider.maximumValue)
    {
        highFilterValue = self.lowSlider.maximumValue;
    }
    
    [self.highSlider setValue:highFilterValue];
    self.highTI.text = [NSString stringWithFormat:@"%d",(int)highFilterValue];
    
    BOOL notchIsOn = [[defaults valueForKey:@"notchFilterOn"] boolValue];
    [self.notchFilterSwitch setOn:notchIsOn];
    
    
    
}

- (void)saveSettings
{
    NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [defaults setValue:[NSNumber numberWithFloat:self.lowSlider.value] forKey:@"lowFilterFreq"];
    [defaults setValue:[NSNumber numberWithFloat:self.highSlider.value] forKey:@"highFilterFreq"];
    [defaults setValue:[NSNumber numberWithBool: self.notchFilterSwitch.on] forKey:@"notchFilterOn"];
    
    [defaults synchronize];
}


- (IBAction)lowSliderValueChanged:(UISlider *)sender {
    //float tempFloat = self.lowSlider.value;
    self.lowTI.text = [NSString stringWithFormat:@"%d",(int)self.lowSlider.value];
}

- (IBAction)highSliderValueChanged:(UISlider *)sender {
    self.highTI.text = [NSString stringWithFormat:@"%d",(int)self.highSlider.value];
}

-(BOOL) setSliderValuesFromTI
{
    NSNumber * tempNumber = [[[NSNumber alloc] initWithFloat:0.0f] autorelease];
    if([self stringIsNumeric:self.lowTI.text andNumber:&tempNumber] && [tempNumber floatValue]>0.0)
    {
        
        [self.lowSlider setValue:[tempNumber floatValue]];
    }
    else
    {
        [self validationAlertWithText:@"Enter valid number for low cutoff frequency."];
        return NO;
    }
    
    tempNumber = [[[NSNumber alloc] initWithFloat:0.0f] autorelease];
    if([self stringIsNumeric:self.highTI.text andNumber:&tempNumber] && [tempNumber floatValue]>0.0)
    {
        
        [self.highSlider setValue:[tempNumber floatValue]];
    }
    else
    {
        [self validationAlertWithText:@"Enter valid number for high cutoff frequency."];
        return NO;
    }
    return YES;
}



-(BOOL) stringIsNumeric:(NSString *) str andNumber: (NSNumber**) outNumberValue
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setDecimalSeparator:@"."];
    *outNumberValue = [formatter numberFromString:str];
    [formatter release];
    return !!(*outNumberValue); // If the string is not numeric, number will be nil
}

-(void) validationAlertWithText:(NSString *) errorString
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Invalid value" message:errorString
                                                   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
    [alert show];
    [alert release];
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
    [self setSliderValuesFromTI];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}


/*
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

*/




- (void)dealloc {
    [_lowTI release];
    [_lowSlider release];
    [_highTI release];
    [_highSlider release];
    [_notchFilterSwitch release];
    [super dealloc];
}

@end
