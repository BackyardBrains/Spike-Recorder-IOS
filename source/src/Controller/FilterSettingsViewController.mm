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
    double SLIDER_VALUE_MAX;
    double SLIDER_VALUE_MIN;
    double REAL_VALUE_MAX;
    double REAL_VALUE_MIN;
    double ZERRO_NEGATIVE_OFFSET;
}

@end

@implementation FilterSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.lowTI.delegate = self;
    self.highTI.delegate = self;
    
    ZERRO_NEGATIVE_OFFSET = 0.1;
    
  
    for (id current in self.rangeSlider.subviews)
    {
        if ([current isKindOfClass:[UISlider class]])
        {
            UISlider *volumeSlider = (UISlider *)current;
            volumeSlider.minimumTrackTintColor = [UIColor redColor];
            volumeSlider.maximumTrackTintColor = [UIColor lightGrayColor];
        }
    }
  
    REAL_VALUE_MIN = 1;
    REAL_VALUE_MAX = (int)([[BBAudioManager bbAudioManager] sourceSamplingRate]*0.29999999);
    
    SLIDER_VALUE_MIN = log(REAL_VALUE_MIN);
    SLIDER_VALUE_MAX = log(REAL_VALUE_MAX);//[[BBAudioManager bbAudioManager] sourceSamplingRate]*0.29999999;
    self.rangeSlider.minimumValue = SLIDER_VALUE_MIN-ZERRO_NEGATIVE_OFFSET;
    self.rangeSlider.maximumValue = SLIDER_VALUE_MAX;
    self.rangeSlider.minimumRange = 0;//between handles
    self.rangeSlider.stepValueContinuously = YES;
    self.rangeSlider.continuous = YES;
    
    if([[BBAudioManager bbAudioManager] getLPFilterCutoff]<1)
    {
        self.rangeSlider.upperValue = self.rangeSlider.minimumValue;
    }
    else
    {
        self.rangeSlider.upperValue = log([[BBAudioManager bbAudioManager] getLPFilterCutoff]);
    }
    
    
    if([[BBAudioManager bbAudioManager] getHPFilterCutoff]<1)
    {
        self.rangeSlider.lowerValue = self.rangeSlider.minimumValue;
    }
    else
    {
        float value =[[BBAudioManager bbAudioManager] getHPFilterCutoff] ;
        float logValue = log(value);
        self.rangeSlider.lowerValue = logValue;//log([[BBAudioManager bbAudioManager] getHPFilterCutoff]);
    }
    
    

    [self rangeSliderValueChanged:nil];
    
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(makeKeyboardDisapear)];
    // prevents the scroll view from swallowing up the touch event of child buttons
    tapGesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapGesture];
    [tapGesture release];

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
    
    //[self loadSettings];
    [self addDoneButton];
    
    
    
    UIImage* image = nil;
    
    /*
     image = [UIImage imageNamed:@"slider-metal-trackBackground"];
     image = [image resizableImageWithCapInsets:UIEdgeInsetsMake(0.0, 5.0, 0.0, 5.0)];
     slider.trackBackgroundImage = image;
     */
    
     image = [UIImage imageNamed:@"slider-metal-track"];
     image = [image resizableImageWithCapInsets:UIEdgeInsetsMake(0.0, 7.0, 0.0, 7.0)];
     //self.rangeSlider.trackImage = image;
    
    /*
     image = [UIImage imageNamed:@"slider-metal-handle"];
     image = [image imageWithAlignmentRectInsets:UIEdgeInsetsMake(-1, 2, 1, 2)];
     slider.lowerHandleImageNormal = image;
     slider.upperHandleImageNormal = image;
     
     image = [UIImage imageNamed:@"slider-metal-handle-highlighted"];
     image = [image imageWithAlignmentRectInsets:UIEdgeInsetsMake(-1, 2, 1, 2)];
     slider.lowerHandleImageHighlighted = image;
     slider.upperHandleImageHighlighted = image;
     */
    

    
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
  //  [self saveSettings];
}

- (void)addDoneButton {
    UIToolbar* keyboardToolbar = [[UIToolbar alloc] init];
    [keyboardToolbar sizeToFit];
    UIBarButtonItem *flexBarButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                      target:nil action:nil];
    UIBarButtonItem *doneBarButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                      target:self.view action:@selector(endEditing:)];
    keyboardToolbar.items = @[flexBarButton, doneBarButton];
    self.lowTI.inputAccessoryView = keyboardToolbar;
    self.highTI.inputAccessoryView = keyboardToolbar;
}

-(void) applyFilter:(id) sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)loadSettings
{
    
  /*  NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    float lowFilterValue = [[defaults valueForKey:@"lowFilterFreq"] floatValue];
    
    // Set the slider to have the bounds of the audio file's duraiton
    self.lowSlider.minimumValue = 0;
    self.lowSlider.maximumValue = [[BBAudioManager bbAudioManager] sourceSamplingRate]*0.29999999;

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
    self.highSlider.maximumValue = [[BBAudioManager bbAudioManager] sourceSamplingRate]*0.29999999;
    
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
    [self.notchFilterSwitch setOn:notchIsOn];*/
}

- (void)saveSettings
{
  /*  NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [defaults setValue:[NSNumber numberWithFloat:self.lowSlider.value] forKey:@"lowFilterFreq"];
    [defaults setValue:[NSNumber numberWithFloat:self.highSlider.value] forKey:@"highFilterFreq"];
    [defaults setValue:[NSNumber numberWithBool: self.notchFilterSwitch.on] forKey:@"notchFilterOn"];
    
    [defaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:FILTER_PARAMETERS_CHANGED object:self];
   */
}

/*
- (IBAction)lowSliderValueChanged:(UISlider *)sender {
    //float tempFloat = self.lowSlider.value;
    self.lowTI.text = [NSString stringWithFormat:@"%d",(int)self.lowSlider.value];
}

- (IBAction)highSliderValueChanged:(UISlider *)sender {
    self.highTI.text = [NSString stringWithFormat:@"%d",(int)self.highSlider.value];
}
*/
-(BOOL) setSliderValuesFromTI
{
    NSNumber * tempNumber = [[[NSNumber alloc] initWithFloat:0.0f] autorelease];
    if([self stringIsNumeric:self.lowTI.text andNumber:&tempNumber] && ([tempNumber floatValue] >= 0.0f) && ([tempNumber floatValue]<=[[BBAudioManager bbAudioManager] sourceSamplingRate]*0.3))
    {
        
       if([tempNumber floatValue]<1.0)
       {
           self.rangeSlider.lowerValue =  SLIDER_VALUE_MIN-ZERRO_NEGATIVE_OFFSET;
       }
       else
       {
           self.rangeSlider.lowerValue = log([tempNumber floatValue]);
       }
    }
    else
    {
        [self validationAlertWithText:@"Enter valid number for low cutoff frequency. (0 - Fs/3)"];
        return NO;
    }
    
    tempNumber = [[[NSNumber alloc] initWithFloat:0.0f] autorelease];
    if([self stringIsNumeric:self.highTI.text andNumber:&tempNumber]  && ([tempNumber floatValue] >= 0.0f) && ([tempNumber floatValue]<=[[BBAudioManager bbAudioManager] sourceSamplingRate]*0.3))
    {
        
        if([tempNumber floatValue]<1.0)
        {
            self.rangeSlider.upperValue =  SLIDER_VALUE_MIN-ZERRO_NEGATIVE_OFFSET;
        }
        else
        {
            self.rangeSlider.upperValue = log([tempNumber floatValue]);
        }
    }
    else
    {
        [self validationAlertWithText:@"Enter valid number for high cutoff frequency. (0 - Fs/3)"];
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

*/
-(void) makeKeyboardDisapear
{
    [self.lowTI resignFirstResponder];
    [self.highTI resignFirstResponder];
}














- (void)dealloc {
    [_lowTI release];
   // [_lowSlider release];
    [_highTI release];
   // [_highSlider release];
   // [_notchFilterSwitch release];
    [_rangeSlider release];
    [super dealloc];
}

- (IBAction)rangeSliderValueChanged:(id)sender {
    
    
    if(self.rangeSlider.lowerValue<0.0)
    {
        self.lowTI.text = [NSString stringWithFormat:@"%d",0];
    }
    else
    {
        self.lowTI.text =  [NSString stringWithFormat:@"%d",(int)exp(self.rangeSlider.lowerValue)];
    }
    
    if(self.rangeSlider.upperValue<0.0)
    {
        self.highTI.text = [NSString stringWithFormat:@"%d",0];
    }
    else
    {
        self.highTI.text =  [NSString stringWithFormat:@"%d",(int)exp(self.rangeSlider.upperValue)];
    }
}

- (IBAction)doneButtonClick:(id)sender {
    [self.masterDelegate finishedWithConfiguration];
    int lowValue = (int)exp(self.rangeSlider.lowerValue);
    int upperValue = (int)exp(self.rangeSlider.upperValue);
    if(upperValue>=REAL_VALUE_MAX-1)
    {
        upperValue = FILTER_LP_OFF;
    }
    
    if(lowValue <1)
    {
        lowValue = FILTER_HP_OFF;
    }
    
    
    [[BBAudioManager bbAudioManager] setFilterLPCutoff:upperValue hpCutoff:lowValue];
    
}
@end
