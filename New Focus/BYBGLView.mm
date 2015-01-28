//
//  BYBGLView.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 1/26/15.
//  Copyright (c) 2015 Datta Lab, Harvard University. All rights reserved.
//

#import "BYBGLView.h"

@implementation BYBGLView

+(UIColor *) getSpikeTrainColorWithIndex:(int) iindex transparency:(float) transp
{
    iindex = iindex%5;
    switch (iindex) {
        
        case 0:
            return [UIColor colorWithRed:1.0f green:0.011764705882352941f blue:0.011764705882352941f alpha:transp];
        case 1:
            return [UIColor colorWithRed:0.9882352941176471f green:0.9372549019607843f blue:0.011764705882352941f alpha:transp];
        case 2:
            return [UIColor colorWithRed:0.0f green:0.0f blue:1.0f alpha:transp];
        case 3:
            return [UIColor colorWithRed:1.0f green:0.0f blue:1.0f alpha:transp];
        case 4:
            return [UIColor colorWithRed:0.9686274509803922f green:0.4980392156862745f blue:0.011764705882352941f alpha:transp];
    }
    return [UIColor colorWithRed:1.0f green:0.0f blue:1.0f alpha:transp];
}


//
// Chenge color according to index
//
-(void) setGLColor:(UIColor *) theColor
{

    CGFloat red,green,blue, talpha;
    [theColor getRed:&red green:&green blue:&blue alpha:&talpha];
    glColor4f(red , green, blue, talpha);

}


@end
