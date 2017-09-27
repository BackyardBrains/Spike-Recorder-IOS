//
//  ChooseFilterTypeViewController.m
//  Spike Recorder
//
//  Created by Stanislav Mircic on 9/21/17.
//  Copyright © 2017 Datta Lab, Harvard University. All rights reserved.
//

#import "ChooseFilterTypeViewController.h"
#import "BBAudioManager.h"
#define RGB(r, g, b) [UIColor colorWithRed:(float)r / 255.0 green:(float)g / 255.0 blue:(float)b / 255.0 alpha:1.0]
@interface ChooseFilterTypeViewController ()

@end

@implementation ChooseFilterTypeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self setBackgroundColor];
}

-(void) setBackgroundColor
{
    
    _rawButton.backgroundColor =  RGB(226, 226, 226);
    _heartButton.backgroundColor =  RGB(226, 226, 226);
    _brainButton.backgroundColor =  RGB(226, 226, 226);
    _plantButton.backgroundColor =  RGB(226, 226, 226);
    _customButton.backgroundColor =  RGB(226, 226, 226);
    switch ([[BBAudioManager bbAudioManager] currentFilterSettings]) {
        case FILTER_SETTINGS_RAW:
            _rawButton.backgroundColor = [UIColor orangeColor];
            break;
        case FILTER_SETTINGS_EKG:
            _heartButton.backgroundColor = [UIColor orangeColor];
            break;
        case FILTER_SETTINGS_EEG:
            _brainButton.backgroundColor = [UIColor orangeColor];
            break;
        case FILTER_SETTINGS_PLANT:
            _plantButton.backgroundColor = [UIColor orangeColor];
            break;
        case FILTER_SETTINGS_CUSTOM:
            _customButton.backgroundColor = [UIColor orangeColor];
            break;
        default:
            break;
    }


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
    [_rawButton release];
    [_heartButton release];
    [_brainButton release];
    [_plantButton release];
    [_customButton release];
    [super dealloc];
}
- (IBAction)rawClick:(id)sender {
    
    [[BBAudioManager bbAudioManager] setFilterSettings:FILTER_SETTINGS_RAW];
    [self setBackgroundColor];
    [self.delegate endSelectionOfFilters:FILTER_SETTINGS_RAW];
}

- (IBAction)heartClick:(id)sender {
    [[BBAudioManager bbAudioManager] setFilterSettings:FILTER_SETTINGS_EKG];
    [self setBackgroundColor];
    [self.delegate endSelectionOfFilters:FILTER_SETTINGS_EKG];
}

- (IBAction)brainClick:(id)sender {
    [[BBAudioManager bbAudioManager] setFilterSettings:FILTER_SETTINGS_EEG];
    [self setBackgroundColor];
    [self.delegate endSelectionOfFilters:FILTER_SETTINGS_EEG];
}

- (IBAction)plantClick:(id)sender {
    [[BBAudioManager bbAudioManager] setFilterSettings:FILTER_SETTINGS_PLANT];
    [self setBackgroundColor];
    [self.delegate endSelectionOfFilters:FILTER_SETTINGS_PLANT];
}

- (IBAction)customClick:(id)sender {
    [[BBAudioManager bbAudioManager] setFilterSettings:FILTER_SETTINGS_CUSTOM];
    [self setBackgroundColor];
    [self.delegate endSelectionOfFilters:FILTER_SETTINGS_CUSTOM];
}
@end
