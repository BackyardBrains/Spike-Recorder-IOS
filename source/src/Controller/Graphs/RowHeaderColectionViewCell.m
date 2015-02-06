//
//  RowHeaderColectionViewCell.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/15/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "RowHeaderColectionViewCell.h"

@interface RowHeaderColectionViewCell ()
{
    UILabel * labelForTitle;
    int numOfCell;
}
@end


@implementation RowHeaderColectionViewCell

@synthesize titleOfRow = _titleOfRow;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _titleOfRow = @"";

        self.backgroundColor = [UIColor blackColor];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(endChangingSize:) name:@"kEndChangeCellSizeInMatrixView" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startChangingSize:) name:@"kStartChangeCellSizeInMatrixView" object:nil];
    }
    return self;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"kStartChangeCellSizeInMatrixView" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"kEndChangeCellSizeInMatrixView" object:nil];
    [super dealloc];
}


//
// Trigered on start of screen rotation
//
-(void) startChangingSize:(NSNotification *)notification
{
    if(labelForTitle)
    {
        [labelForTitle setHidden:YES];
    }
}


//
// Trigered on end of screen rotation
//
-(void) endChangingSize:(NSNotification *)notification
{
    if(labelForTitle)
    {
        
        [labelForTitle setFrame:CGRectMake(2, 0, 8, self.frame.size.height)];
        
        if(self.frame.size.height>100)
        {
            _titleOfRow = [NSString stringWithFormat:@"Spike Train %d",numOfCell];
        }
        else if(self.frame.size.height>25)
        {
            _titleOfRow = [NSString stringWithFormat:@"ST%d",numOfCell];
        }
        else
        {
            _titleOfRow = [NSString stringWithFormat:@"%d",numOfCell];
        }
        labelForTitle.text = _titleOfRow;
        [labelForTitle setHidden:NO];
    }
}



-(void) setNumberForTitleOfRow:(int) numOfRow
{
    
    numOfCell = numOfRow;
    if(self.frame.size.height>100)
    {
        _titleOfRow = [NSString stringWithFormat:@"Spike Train %d",numOfCell];
    }
    else if(self.frame.size.height>25)
    {
        _titleOfRow = [NSString stringWithFormat:@"ST%d",numOfCell];
    }
    else
    {
        _titleOfRow = [NSString stringWithFormat:@"%d",numOfCell];
    }
    
    if(labelForTitle==nil)
    {
        labelForTitle = [[UILabel alloc] initWithFrame:CGRectMake(-self.frame.size.height*0.5+10, self.frame.size.height*0.5, self.frame.size.height, 13)];

        labelForTitle.backgroundColor = [UIColor blackColor];
        labelForTitle.textColor = [UIColor whiteColor];
        labelForTitle.numberOfLines = 1;
        labelForTitle.lineBreakMode = NSLineBreakByCharWrapping;
        labelForTitle.textAlignment = NSTextAlignmentCenter;
        labelForTitle.font = [UIFont fontWithName:@"Georgia" size:(11)];
        [self addSubview:labelForTitle];
        //labelForTitle.layer.anchorPoint = CGPointMake(1,0);
        labelForTitle.transform = CGAffineTransformMakeRotation((M_PI)/2);

    }
    labelForTitle.text = _titleOfRow;

}


@end
