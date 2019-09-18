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
            return [UIColor colorWithRed:0.0f green:1.0f blue:0.0f alpha:transp];
        case 3:
            return [UIColor colorWithRed:1.0f green:0.0f blue:1.0f alpha:transp];
        case 4:
            return [UIColor colorWithRed:0.9686274509803922f green:0.4980392156862745f blue:0.011764705882352941f alpha:transp];
    }
    return [UIColor colorWithRed:1.0f green:0.0f blue:1.0f alpha:transp];
}

/*
 const Widgets::Color AudioView::MARKER_COLORS[] = {
 Widgets::Color(216, 180, 231),
 Widgets::Color(176, 229, 124),
 Widgets::Color(255, 80, 0),  //orange
 Widgets::Color(255, 236, 148),/
 Widgets::Color(255, 174, 174),/
 Widgets::Color(180, 216, 231),/
 Widgets::Color(193, 218, 214),/
 Widgets::Color(172, 209, 233),/
 Widgets::Color(174, 255, 174),
 Widgets::Color(255, 236, 255),
 };
 */
+(UIColor *) getEventColorWithIndex:(int) iindex transparency:(float) transp
{
    
    iindex = iindex%10;
    switch (iindex) {
            
        case 0:
            return [UIColor colorWithRed:0.84705882352f green:0.7058823529f blue:0.90588235294f alpha:transp];
        case 1:
            return [UIColor colorWithRed:0.69019607843f green:0.89803921568f blue:0.4862745098f alpha:transp];
        case 2:
            return [UIColor colorWithRed:1.0f green:0.31372549019f blue:0.0f alpha:transp];//orange
        case 3:
            return [UIColor colorWithRed:1.0f green:0.92549019607f blue:0.58039215686f alpha:transp];//
        case 4:
            return [UIColor colorWithRed:1.0f green:0.68235294117f blue:0.68235294117f alpha:transp];//
        case 5:
            return [UIColor colorWithRed:0.70588235294f green:0.84705882352f blue:0.90588235294f alpha:transp];//
        case 6:
            return [UIColor colorWithRed:0.75686274509f green:0.85490196078f blue:0.83921568627f alpha:transp];//
        case 7:
            return [UIColor colorWithRed:0.67450980392f green:0.81960784313f blue:0.91372549019f alpha:transp];//
        case 8:
            return [UIColor colorWithRed:0.68235294117f green:1.0f blue:0.68235294117f alpha:transp];
        case 9:
            return [UIColor colorWithRed:1.0f green:0.92549019607f blue:1.0f alpha:transp];
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
