//
//  SelectFilterPresetView.m
//  Spike Recorder
//
//  Created by Stanislav on 15/03/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import "SelectFilterPresetView.h"
#define ROUND_BUTTON_WIDTH_HEIGHT 60
#define SPACE_BETWEEN_BUTTONS 11
#define NUMBER_OF_BUTTONS 5
#define UNSELECT_ALL_INDEX 100
@implementation SelectFilterPresetView


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    _buttons = [[NSMutableArray alloc] initWithCapacity:0];
    for (int buttonIndex=0;buttonIndex<NUMBER_OF_BUTTONS;buttonIndex++)
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [_buttons addObject:button];
        //width and height should be same value
        button.frame = CGRectMake(buttonIndex*(ROUND_BUTTON_WIDTH_HEIGHT+SPACE_BETWEEN_BUTTONS), 0, ROUND_BUTTON_WIDTH_HEIGHT, ROUND_BUTTON_WIDTH_HEIGHT);
        button.tag = buttonIndex;
        switch (buttonIndex) {
            case ecgPreset:
                [button setTitle: @"ECG" forState:UIControlStateNormal];
                break;
            case eegPreset:
                [button setTitle: @"EEG" forState:UIControlStateNormal];
                break;
            case emgPreset:
                [button setTitle: @"EMG" forState:UIControlStateNormal];
                break;
            case plantPreset:
                [button setTitle: @"Plant" forState:UIControlStateNormal];
                break;
            case neuronPreset:
                [button setTitle: @"Neuron" forState:UIControlStateNormal];
                break;
            default:
                break;
        }
        
        [button addTarget:self action:@selector(roundButtonDidTap:) forControlEvents:UIControlEventTouchUpInside];
        button.titleLabel.font = [UIFont fontWithName:@"ComicBook-BoldItalic" size:16.0f];
        [button setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
        //Clip/Clear the other pieces whichever outside the rounded corner
        button.clipsToBounds = YES;
        
        //half of the width
        button.layer.cornerRadius = ROUND_BUTTON_WIDTH_HEIGHT/2.0f;
        button.layer.borderColor=[UIColor grayColor].CGColor;
        button.layer.borderWidth=1.0f;
        
        button.layer.shadowColor = [UIColor whiteColor].CGColor;
        button.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0,0, (ROUND_BUTTON_WIDTH_HEIGHT), ROUND_BUTTON_WIDTH_HEIGHT) cornerRadius:ROUND_BUTTON_WIDTH_HEIGHT].CGPath;
        button.layer.shadowRadius = 2.0f;
        button.layer.shadowOpacity = .95;
        button.layer.shadowOffset = CGSizeZero;
        button.layer.masksToBounds = NO;
        
        [self addSubview:button];
    }
}

-(void) deselectAll
{
    self.selectedType = UNSELECT_ALL_INDEX;
    [self selectOnlyOne];
}

-(void) roundButtonDidTap:(id) sender
{
    self.selectedType = ((UIButton*)sender).tag;
    [self selectOnlyOne];
    [self.delegate endSelectionOfFilterPreset:self.selectedType];
    
}

-(void) selectOnlyOne
{
    for(int i=0;i<NUMBER_OF_BUTTONS;i++)
    {
        UIButton * tempButton = (UIButton *)[_buttons objectAtIndex:i];
        if(i==self.selectedType)
        {
            tempButton.layer.shadowColor = [UIColor orangeColor].CGColor;
            [tempButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        }
        else
        {
            tempButton.layer.shadowColor = [UIColor whiteColor].CGColor;
            [tempButton setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
        }
    }
}
@end
