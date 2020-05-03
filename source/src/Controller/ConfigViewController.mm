//
//  ConfigViewController.m
//  Spike Recorder
//
//  Created by Stanislav on 15/03/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import "ConfigViewController.h"
#import "ChannelColorsTableViewCell.h"
#import "BBAudioManager.h"
@interface ConfigViewController ()
{
    double SLIDER_VALUE_MAX;
    double SLIDER_VALUE_MIN;
    double REAL_VALUE_MAX;
    double REAL_VALUE_MIN;
    double ZERRO_NEGATIVE_OFFSET;
}
@end

@implementation ConfigViewController
@synthesize selectNotchFilter;
@synthesize lowTI;
@synthesize highTI;
@synthesize channelsTableView;
@synthesize rangeSelector;
@synthesize filterPresetSelection;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.

    [selectNotchFilter setTitleTextAttributes:@{NSFontAttributeName :[UIFont fontWithName:@"ComicBook-BoldItalic" size:16.0] } forState:UIControlStateNormal];

    channelsTableView.dataSource = self;
    channelsTableView.delegate = self;
    channelsTableView.allowsSelection = false;

    [self setupFilters];
    [self addCustomKeyboard];
}

-(void) setupFilters
{
    self.lowTI.delegate = self;
    self.highTI.delegate = self;
    
    ZERRO_NEGATIVE_OFFSET = 0.1;

    REAL_VALUE_MIN = 1;
    REAL_VALUE_MAX = 500;
    
    SLIDER_VALUE_MIN = log(REAL_VALUE_MIN);
    SLIDER_VALUE_MAX = log(REAL_VALUE_MAX);//[[BBAudioManager bbAudioManager] sourceSamplingRate]*0.29999999;
    self.rangeSelector.minimumValue = SLIDER_VALUE_MIN-ZERRO_NEGATIVE_OFFSET;
    self.rangeSelector.maximumValue = SLIDER_VALUE_MAX;
    self.rangeSelector.minimumRange = 0;//between handles
    self.rangeSelector.stepValueContinuously = YES;
    self.rangeSelector.continuous = YES;
    
    if([[BBAudioManager bbAudioManager] getLPFilterCutoff]<1)
    {
        self.rangeSelector.upperValue = self.rangeSelector.minimumValue;
    }
    else
    {
        self.rangeSelector.upperValue = log([[BBAudioManager bbAudioManager] getLPFilterCutoff]);
    }
    
    
    if([[BBAudioManager bbAudioManager] getHPFilterCutoff]<1)
    {
        self.rangeSelector.lowerValue = self.rangeSelector.minimumValue;
    }
    else
    {
        float value =[[BBAudioManager bbAudioManager] getHPFilterCutoff] ;
        float logValue = log(value);
        self.rangeSelector.lowerValue = logValue;//log([[BBAudioManager bbAudioManager] getHPFilterCutoff]);
    }
    
    
    
    [self rangeSelectrorValueChanged:self.rangeSelector];
    
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(makeKeyboardDisapear)];
    // prevents the scroll view from swallowing up the touch event of child buttons
    tapGesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapGesture];
    [tapGesture release];
    
    
}

-(void) addCustomKeyboard
{
    UIToolbar* keyboardToolbar = [[[UIToolbar alloc] init] autorelease];
    [keyboardToolbar sizeToFit];
    UIBarButtonItem *flexBarButton = [[[UIBarButtonItem alloc]
                                       initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                       target:nil action:nil] autorelease];
    UIBarButtonItem *doneBarButton = [[[UIBarButtonItem alloc]
                                       initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                       target:self.view action:@selector(endEditing:)] autorelease];
    keyboardToolbar.items = @[flexBarButton, doneBarButton];
    self.lowTI.inputAccessoryView = keyboardToolbar;
    self.highTI.inputAccessoryView = keyboardToolbar;
}
#pragma mark - Filter settings

//from FilterPresetType.h from FilterPresetDelegateProtocol
- (void)endSelectionOfFilterPreset:(FilterPresetType) filterType
{
    
}

-(BOOL) setSliderValuesFromTI
{
    NSNumber * tempNumber = [[[NSNumber alloc] initWithFloat:0.0f] autorelease];
    if([self stringIsNumeric:self.lowTI.text andNumber:&tempNumber] && ([tempNumber floatValue] >= 0.0f) && ([tempNumber floatValue]<=REAL_VALUE_MAX))
    {
        
        if([tempNumber floatValue]<1.0)
        {
            self.rangeSelector.lowerValue =  SLIDER_VALUE_MIN-ZERRO_NEGATIVE_OFFSET;
        }
        else
        {
            self.rangeSelector.lowerValue = log([tempNumber floatValue]);
        }
    }
    else
    {
        [self validationAlertWithText:[NSString stringWithFormat:@"Enter valid number for low cutoff frequency. (0 - %dHz)",(int)REAL_VALUE_MAX]];
        return NO;
    }
    
    tempNumber = [[[NSNumber alloc] initWithFloat:0.0f] autorelease];
    if([self stringIsNumeric:self.highTI.text andNumber:&tempNumber]  && ([tempNumber floatValue] >= 0.0f) && ([tempNumber floatValue]<=REAL_VALUE_MAX))
    {
        
        if([tempNumber floatValue]<1.0)
        {
            self.rangeSelector.upperValue =  SLIDER_VALUE_MIN-ZERRO_NEGATIVE_OFFSET;
        }
        else
        {
            self.rangeSelector.upperValue = log([tempNumber floatValue]);
        }
    }
    else
    {
        [self validationAlertWithText:[NSString stringWithFormat:@"Enter valid number for low cutoff frequency. (0 - %dHz)",(int)REAL_VALUE_MAX]];
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
    /*UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Invalid value" message:errorString
                                                   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
    [alert show];
    [alert release];
    */
    
      UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"Invalid value" message:errorString preferredStyle:UIAlertControllerStyleAlert];
     
     [actionSheet addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action)
     {
         //[self dismissViewControllerAnimated:YES completion:^{}];
     }]];
     
     // Present action sheet.
     [self presentViewController:actionSheet animated:YES completion:nil];
    
}




- (IBAction)rangeSelectrorValueChanged:(id)sender {
    
    if(self.rangeSelector.lowerValue<0.0)
    {
        self.lowTI.text = [NSString stringWithFormat:@"%d",0];
    }
    else
    {
        self.lowTI.text =  [NSString stringWithFormat:@"%d",(int)exp(self.rangeSelector.lowerValue)];
    }
    
    if(self.rangeSelector.upperValue<0.0)
    {
        self.highTI.text = [NSString stringWithFormat:@"%d",0];
    }
    else
    {
        self.highTI.text =  [NSString stringWithFormat:@"%d",(int)exp(self.rangeSelector.upperValue)];
    }
}

#pragma mark - Keyboard stuff


- (void)textFieldDidEndEditing:(UITextField *)textField
{
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

#pragma mark - Channels Table view delegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[BBAudioManager bbAudioManager] sourceNumberOfChannels];;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
     static NSString *CellIdentifier = @"iChannelColorsTableViewCell";
    ChannelColorsTableViewCell *cell =[channelsTableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        [tableView registerNib:[UINib nibWithNibName:@"ChannelColorsTableViewCell" bundle:nil] forCellReuseIdentifier:@"iChannelColorsTableViewCell"];
        cell = [tableView dequeueReusableCellWithIdentifier:@"iChannelColorsTableViewCell"];
       
    }
    cell.colorChooser.nameLabel.text = [NSString stringWithFormat:@"Channel %ld", (long)indexPath.row];

    if (channelsTableView.contentSize.height < channelsTableView.frame.size.height) {
        channelsTableView.scrollEnabled = NO;
    }
    else {
        channelsTableView.scrollEnabled = YES;
    }
    return cell;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 80;
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/


- (IBAction)closeVIewTap:(id)sender {
    [_masterDelegate finishedWithConfiguration];
}



- (void)dealloc {
    [lowTI release];
    [selectNotchFilter release];
    [highTI release];
    [channelsTableView release];
    [rangeSelector release];
    [filterPresetSelection release];
    [super dealloc];
}
@end
