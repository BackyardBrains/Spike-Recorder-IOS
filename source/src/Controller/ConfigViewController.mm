//
//  ConfigViewController.m
//  Spike Recorder
//
//  Created by Stanislav on 15/03/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import "ConfigViewController.h"
#import "BBAudioManager.h"
#import "ChannelConfig.h"

#define SEGMENTED_NOTCH_NO_FILTER_INDEX 0
#define SEGMENTED_NOTCH_50_HZ_INDEX 1
#define SEGMENTED_NOTCH_60_HZ_INDEX 2

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

    filterPresetSelection.delegate = self;
    
    [self setupFilters];
    [self addCustomKeyboard];
}

-(void) setupFilters
{
    self.lowTI.delegate = self;
    self.highTI.delegate = self;
    
    ZERRO_NEGATIVE_OFFSET = 0.1;

    REAL_VALUE_MIN = 1;
    REAL_VALUE_MAX = [[BBAudioManager bbAudioManager] sourceSamplingRate]*0.499999999;
    
    SLIDER_VALUE_MIN = log(REAL_VALUE_MIN);
    SLIDER_VALUE_MAX = log(REAL_VALUE_MAX);
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
    
    if([[BBAudioManager bbAudioManager] isNotchON])
    {
        if([[BBAudioManager bbAudioManager] is60HzNotchON])
        {
            selectNotchFilter.selectedSegmentIndex = SEGMENTED_NOTCH_60_HZ_INDEX;
        }
        else
        {
            selectNotchFilter.selectedSegmentIndex = SEGMENTED_NOTCH_50_HZ_INDEX;
        }
    }
    else
    {
        selectNotchFilter.selectedSegmentIndex = SEGMENTED_NOTCH_NO_FILTER_INDEX;
    }
    [self checkFilterValuesAndLightUpButtons];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshScreen) name:RESETUP_SCREEN_NOTIFICATION object:nil];
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    
    [_masterDelegate configIsClossing];
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:RESETUP_SCREEN_NOTIFICATION object:nil];
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
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(makeKeyboardDisapear)];
    // prevents the scroll view from swallowing up the touch event of child buttons
    tapGesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapGesture];
    [tapGesture release];
}
#pragma mark - Filter settings

//from FilterPresetType.h from FilterPresetDelegateProtocol
- (void)endSelectionOfFilterPreset:(FilterPresetType) filterType
{
    switch (filterType) {
        case ecgPreset:
            [self setLPValue: 100.0 HPValue:1.0 notch:SEGMENTED_NOTCH_60_HZ_INDEX];
            [self setLPValue: 100.0 HPValue:1.0 notch:SEGMENTED_NOTCH_60_HZ_INDEX];
            break;
        case eegPreset:
            [self setLPValue: 50.0 HPValue:0.0 notch:SEGMENTED_NOTCH_60_HZ_INDEX];
            [self setLPValue: 50.0 HPValue:0.0 notch:SEGMENTED_NOTCH_60_HZ_INDEX];
            break;
        case emgPreset:
            [self setLPValue: 2500.0 HPValue:70.0 notch:SEGMENTED_NOTCH_60_HZ_INDEX];
            [self setLPValue: 2500.0 HPValue:70.0 notch:SEGMENTED_NOTCH_60_HZ_INDEX];
            break;
        case plantPreset:
            [self setLPValue: 5.0 HPValue:0.0 notch:SEGMENTED_NOTCH_60_HZ_INDEX];
            [self setLPValue: 5.0 HPValue:0.0 notch:SEGMENTED_NOTCH_60_HZ_INDEX];
            break;
        case neuronPreset:
            [self setLPValue: 5000.0 HPValue:1.0 notch:SEGMENTED_NOTCH_60_HZ_INDEX];
            [self setLPValue: 5000.0 HPValue:1.0 notch:SEGMENTED_NOTCH_60_HZ_INDEX];
            break;
        default:
            [self setLPValue: 5000.0 HPValue:1.0 notch:SEGMENTED_NOTCH_60_HZ_INDEX];
            [self setLPValue: 5000.0 HPValue:1.0 notch:SEGMENTED_NOTCH_60_HZ_INDEX];
            break;
    }
}

-(void) checkFilterValuesAndLightUpButtons
{
    int lowPass = 0;
    int highPass = 0;
    
    if(self.rangeSelector.lowerValue<0.0)
    {
        highPass = FILTER_HP_OFF;
    }
    else
    {
        highPass = (int)lroundf(exp(self.rangeSelector.lowerValue));
    }
    
    if(self.rangeSelector.upperValue<0.0)
    {
        lowPass = 0;
    }
    else
    {
        lowPass = (int)lroundf(exp(self.rangeSelector.upperValue));
    }
    
    
    if((lowPass == 100) && (highPass==1.0))
    {
        [filterPresetSelection lightUpButtonIndex: ecgPreset];
    }
    else if((lowPass == 50) && (highPass==0))
    {
        [filterPresetSelection lightUpButtonIndex: eegPreset ];
    }
    else if((lowPass == 2500) && (highPass==70))
    {
        [filterPresetSelection lightUpButtonIndex: emgPreset];
    }
    else if((lowPass == 5) && (highPass==0))
    {
        [filterPresetSelection lightUpButtonIndex: plantPreset];
    }
    else if((lowPass == 5000) && (highPass==1))
    {
        [filterPresetSelection lightUpButtonIndex: neuronPreset];
    }
    else
    {
        [filterPresetSelection deselectAll];
    }
        
    
}

-(void) setLPValue:(float) lpValue HPValue:(float) hpValue notch:(int) notchType
{
        if(hpValue > REAL_VALUE_MAX)
        {
            hpValue = REAL_VALUE_MAX;
        }
        if(hpValue<1.0)
        {
            self.rangeSelector.lowerValue =  SLIDER_VALUE_MIN-ZERRO_NEGATIVE_OFFSET;
        }
        else
        {
            self.rangeSelector.lowerValue = log(hpValue);
        }
    
        if(lpValue > REAL_VALUE_MAX)
        {
            lpValue = REAL_VALUE_MAX;
        }
        if(lpValue<1.0)
        {
            self.rangeSelector.upperValue =  SLIDER_VALUE_MIN-ZERRO_NEGATIVE_OFFSET;
        }
        else
        {
            self.rangeSelector.upperValue = log(lpValue);
        }
    
    if(notchType>SEGMENTED_NOTCH_60_HZ_INDEX)
    {
        notchType = SEGMENTED_NOTCH_60_HZ_INDEX;
    }
    if(notchType<SEGMENTED_NOTCH_NO_FILTER_INDEX)
    {
        notchType = SEGMENTED_NOTCH_NO_FILTER_INDEX;
    }
    selectNotchFilter.selectedSegmentIndex = notchType;
    
    [self fillFilterTextFromSlider];
    
}






- (NSUInteger)supportedInterfaceOrientations {

    switch ([UIDevice currentDevice].userInterfaceIdiom) {

        case UIUserInterfaceIdiomPad:
            return UIInterfaceOrientationMaskAll;
        case UIUserInterfaceIdiomPhone:
            return UIInterfaceOrientationMaskPortrait;
        case UIUserInterfaceIdiomUnspecified:
            return UIInterfaceOrientationMaskAll;
            break;
        case UIUserInterfaceIdiomTV:
            return UIInterfaceOrientationMaskAll;
            break;
        case UIUserInterfaceIdiomCarPlay:
            return UIInterfaceOrientationMaskAll;
            break;
        case UIUserInterfaceIdiomMac:
            return UIInterfaceOrientationMaskAll;
            break;
    }
}

- (BOOL)shouldAutorotate {

    return NO;
}


-(BOOL) setSliderValuesFromTI
{
    [filterPresetSelection deselectAll];
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
    
    [self checkFilterValuesAndLightUpButtons];
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


-(void) fillFilterTextFromSlider
{
    if(self.rangeSelector.lowerValue<0.0)
    {
        self.lowTI.text = [NSString stringWithFormat:@"%d",0];
    }
    else
    {
        self.lowTI.text =  [NSString stringWithFormat:@"%d",(int)lroundf(exp(self.rangeSelector.lowerValue))];
    }
    
    if(self.rangeSelector.upperValue<0.0)
    {
        self.highTI.text = [NSString stringWithFormat:@"%d",0];
    }
    else
    {
        self.highTI.text =  [NSString stringWithFormat:@"%d",(int)lroundf(exp(self.rangeSelector.upperValue))];
    }
}

- (IBAction)rangeSelectrorValueChanged:(id)sender {
    
    [self checkFilterValuesAndLightUpButtons];
    //[filterPresetSelection deselectAll];
    [self fillFilterTextFromSlider];
    
}

-(void) saveFilterValues
{
    int lowPass = 0;
    int highPass = 0;
    
    if(self.rangeSelector.lowerValue<0.0)
    {
        highPass = FILTER_HP_OFF;
    }
    else
    {
        highPass = (int)lroundf(exp(self.rangeSelector.lowerValue));
    }
    
    if(self.rangeSelector.upperValue<0.0)
    {
        lowPass = 0;
    }
    else
    {
        lowPass = (int)lroundf(exp(self.rangeSelector.upperValue));
    }
    if(lowPass>=REAL_VALUE_MAX)
    {
        lowPass = FILTER_LP_OFF;
    }
    [[BBAudioManager bbAudioManager] setFilterLPCutoff:lowPass hpCutoff:highPass];
    
    if (selectNotchFilter.selectedSegmentIndex == SEGMENTED_NOTCH_NO_FILTER_INDEX)
    {
        [[BBAudioManager bbAudioManager] turnOFFNotchFilters];
    }
    else if(selectNotchFilter.selectedSegmentIndex == SEGMENTED_NOTCH_50_HZ_INDEX)
    {
        [[BBAudioManager bbAudioManager] turnON50HzNotch];
    }
    else if(selectNotchFilter.selectedSegmentIndex == SEGMENTED_NOTCH_60_HZ_INDEX)
    {
        [[BBAudioManager bbAudioManager] turnON60HzNotch];
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
    return [[[BBAudioManager bbAudioManager] currentlyAvailableInputChannels] count];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
     static NSString *CellIdentifier = @"iChannelColorsTableViewCell";
    ChannelColorsTableViewCell *cell =[channelsTableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        [tableView registerNib:[UINib nibWithNibName:@"ChannelColorsTableViewCell" bundle:nil] forCellReuseIdentifier:@"iChannelColorsTableViewCell"];
        cell = [tableView dequeueReusableCellWithIdentifier:@"iChannelColorsTableViewCell"];
       
    }
    ChannelConfig * tempChannelConfig = (ChannelConfig *)[[[BBAudioManager bbAudioManager] currentlyAvailableInputChannels] objectAtIndex:indexPath.row];
    [cell setToColorIndex:[tempChannelConfig colorIndex]];
    cell.channelConfig = tempChannelConfig;
    cell.colorDelegate = self;
    cell.colorChooser.nameLabel.text = [tempChannelConfig userFriendlyFullName];

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

// ChannelColorsTableViewCell Protocol
-(void) channelColorChanged:(ChannelConfig*) config cell:(ChannelColorsTableViewCell*) cell
{
    if(config.currentlyActive && cell.colorChooser.selectedColorIndex != 0)
    {
        //if we will not turn OFF the channel just change the color of active channel
        config.colorIndex = cell.colorChooser.selectedColorIndex;
        [[BBAudioManager bbAudioManager] updateColorOfActiveChannels];
    }
    else
    {
        //turn ON/OFF channel
        BOOL changeOfChannelWentOK = false;
        config.colorIndex = cell.colorChooser.selectedColorIndex;
        if(config.currentlyActive && cell.colorChooser.selectedColorIndex == 0)
        {
            changeOfChannelWentOK = [[BBAudioManager bbAudioManager] deactivateChannelWithConfig:config];
        }
        if(!config.currentlyActive && cell.colorChooser.selectedColorIndex != 0)
        {
            changeOfChannelWentOK = [[BBAudioManager bbAudioManager] activateChannelWithConfig:config];
        }
        if(cell.colorChooser.selectedColorIndex!=0)
        {
           config.colorIndex = cell.colorChooser.selectedColorIndex;
        }
        [self refreshScreen];
    }
}

-(void) refreshScreen
{
    [ self refreshChannels];
    [self setupFilters];
}

-(void) refreshChannels
{
    [channelsTableView reloadData];
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
    //save all filter values
    [self saveFilterValues];
    
    
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
