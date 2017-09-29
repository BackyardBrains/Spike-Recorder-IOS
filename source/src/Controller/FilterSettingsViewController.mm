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
    
  
}

- (void)saveSettings
{
  
}


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




-(void) makeKeyboardDisapear
{
    [self.lowTI resignFirstResponder];
    [self.highTI resignFirstResponder];
}



- (void)dealloc {
    [_lowTI release];
    [_highTI release];
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
