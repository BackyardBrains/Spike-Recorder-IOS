//
//  ColumnHeaderCollectionViewCell.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/15/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "ColumnHeaderCollectionViewCell.h"

@interface ColumnHeaderCollectionViewCell ()
{
    UILabel * labelForTitle;
    int numOfCell;
}
@end

@implementation ColumnHeaderCollectionViewCell

@synthesize titleOfColumn = _titleOfColumn;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _titleOfColumn = @"";
        self.backgroundColor = [UIColor whiteColor];
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
        
        [labelForTitle setFrame:CGRectMake(1, 2, self.frame.size.width-1, self.frame.size.height-1)];
        if(numOfCell==0)
        {
            _titleOfColumn = @"";
        }
        else
        {
            if(self.frame.size.width>100)
            {
                _titleOfColumn = [NSString stringWithFormat:@"Spike Train %d",numOfCell];
            }
            else if(self.frame.size.width>25)
            {
                _titleOfColumn = [NSString stringWithFormat:@"ST%d",numOfCell];
            }
            else
            {
                _titleOfColumn = [NSString stringWithFormat:@"%d",numOfCell];
            }
        }
        labelForTitle.text = _titleOfColumn;
        [labelForTitle setHidden:NO];
    }
}

-(void) setNumberForTitleOfColumn:(int) numOfColumn
{
    numOfCell = numOfColumn;
    if(numOfCell==0)
    {
        _titleOfColumn = @"";
    }
    else
    {
        if(self.frame.size.width>100)
        {
            _titleOfColumn = [NSString stringWithFormat:@"Spike Train %d",numOfCell];
        }
        else if(self.frame.size.width>25)
        {
            _titleOfColumn = [NSString stringWithFormat:@"ST%d",numOfCell];
        }
        else
        {
            _titleOfColumn = [NSString stringWithFormat:@"%d",numOfCell];
        }
    }

    
    if(labelForTitle==nil)
    {
        labelForTitle = [[UILabel alloc] initWithFrame:CGRectMake(1, 2, self.frame.size.width-1, self.frame.size.height-1)];
        labelForTitle.backgroundColor = [UIColor whiteColor];
        
        labelForTitle.textAlignment = NSTextAlignmentCenter;
        labelForTitle.font = [UIFont fontWithName:@"Georgia" size:(11)];
        [self addSubview:labelForTitle];
    }
    labelForTitle.text = _titleOfColumn;
    
}
@end
