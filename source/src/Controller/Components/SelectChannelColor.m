//
//  SelectChannelColor.m
//  Spike Recorder
//
//  Created by Stanislav on 16/03/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import "SelectChannelColor.h"
#define ROUND_BUTTON_WIDTH_HEIGHT 45
#define SPACE_BETWEEN_BUTTONS 6
#define NUMBER_OF_BUTTONS 7
#define DEGREES_TO_RADIANS(angle) ((angle) / 180.0 * M_PI)

@implementation SelectChannelColor

@synthesize nameLabel;
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    _buttons = [[NSMutableArray alloc] initWithCapacity:0];
    for (int buttonIndex=0;buttonIndex<NUMBER_OF_BUTTONS;buttonIndex++)
    {
        
        nameLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, rect.size.width, 20)];
        nameLabel.text = @"Channel name (this can be longer)";
        nameLabel.font = [UIFont fontWithName:@"ComicBook-BoldItalic" size:16.0f]; //custom font
        nameLabel.numberOfLines = 1;
        nameLabel.baselineAdjustment = YES;
        nameLabel.adjustsFontSizeToFitWidth = YES;
        nameLabel.clipsToBounds = YES;
        nameLabel.backgroundColor = [UIColor clearColor];
        nameLabel.textColor = [UIColor orangeColor];
        nameLabel.textAlignment = NSTextAlignmentLeft;
        [self addSubview:nameLabel];
        
        
        
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [_buttons addObject:button];
        //width and height should be same value
        button.frame = CGRectMake(buttonIndex*(ROUND_BUTTON_WIDTH_HEIGHT+SPACE_BETWEEN_BUTTONS), 25, ROUND_BUTTON_WIDTH_HEIGHT, ROUND_BUTTON_WIDTH_HEIGHT);
        button.tag = buttonIndex;
        
       
        [button addTarget:self action:@selector(roundButtonDidTap:) forControlEvents:UIControlEventTouchUpInside];
        //Clip/Clear the other pieces whichever outside the rounded corner
        button.clipsToBounds = YES;
        
        //half of the width
        button.layer.cornerRadius = ROUND_BUTTON_WIDTH_HEIGHT/2.0f;
        button.layer.borderColor=[UIColor grayColor].CGColor;
        button.layer.borderWidth=1.0f;
        button.layer.backgroundColor = [self setColorWithIndex:buttonIndex transparency:1.0f].CGColor;
        [self addSubview:button];
 
    }
    _selectedColorIndex = 0;
    [self drawMarkOnButtonForIndex:_selectedColorIndex];
    
}

-(void) roundButtonDidTap:(id) sender
{
    _selectedColorIndex = ((UIButton*)sender).tag;
    [self drawMarkOnButtonForIndex:_selectedColorIndex];
    //[self.delegate endSelectionOfFilterPreset:self.selectedType];
}

-(void) drawMarkOnButtonForIndex:(int) indexOfButton
{
    UIButton * tempButton = [_buttons objectAtIndex:indexOfButton];
    int xin = tempButton.frame.origin.x;
    int yin = tempButton.frame.origin.y;
    [selectMarkViewPart1 removeFromSuperview];
    [selectMarkViewPart2 removeFromSuperview];
    [selectMarkViewPart2 release];
    [selectMarkViewPart1 release];
    selectMarkViewPart1 = [[UIView alloc] initWithFrame:CGRectMake(xin+10, yin+29, 13, 3)];
    selectMarkViewPart1.backgroundColor = [UIColor grayColor];
    double rads = DEGREES_TO_RADIANS(45);
    CGAffineTransform transform = CGAffineTransformRotate(CGAffineTransformIdentity, rads);
    selectMarkViewPart1.transform = transform;
    [self addSubview:selectMarkViewPart1];
    
    selectMarkViewPart2 = [[UIView alloc] initWithFrame:CGRectMake(xin+12, yin+20, 28, 3)];
    selectMarkViewPart2.backgroundColor = [UIColor grayColor];
    rads = DEGREES_TO_RADIANS(-65);
    transform = CGAffineTransformRotate(CGAffineTransformIdentity, rads);
    selectMarkViewPart2.transform = transform;
    [self addSubview:selectMarkViewPart2];

}




//Change color of spike marks according to index
-(UIColor *) setColorWithIndex:(int) iindex transparency:(float) transp
{
    iindex = iindex%7;
    switch (iindex) {
        case 0:
            return [UIColor blackColor];
            break;
        case 1:
            return [UIColor colorWithRed:0.45882352941f green:0.98039215686f blue:0.32156862745f alpha:transp];
            break;
        case 2:
            return [UIColor colorWithRed:0.92156862745f green:0.2f blue:0.26666666666f alpha:transp];
            break;
        case 3:
             return [UIColor colorWithRed:0.90588235294f green:0.98039215686f blue:0.45882352941f alpha:transp];
            break;
        case 4:
            return [UIColor colorWithRed:0.94509803921f green:0.56470588235f blue:0.39607843137f alpha:transp];
            break;
        case 5:
            return [UIColor colorWithRed:0.55294117647f green:0.89803921568f blue:0.47843137254f alpha:transp];
            break;
        case 6:
            return [UIColor colorWithRed:0.3294117647f green:0.73725490196f blue:0.77647058823f alpha:transp];
            break;
    }
    return [UIColor blackColor];
}
@end
