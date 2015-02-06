//
//  BYBHandleButton.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 1/26/15.
//  Copyright (c) 2015 BackyardBrains. All rights reserved.
//

#import "BYBHandleButton.h"
#import "BYBGLView.h"
#define RADIUS 11.0
@implementation BYBHandleButton


-(void) nextColor:(UIColor * ) theColor
{
    currentColor = theColor;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    if(currentColor == nil)
    {
        currentColor = [BYBGLView getSpikeTrainColorWithIndex:0 transparency:1.0f];
    }
    
    float startOfCircleX = self.bounds.origin.x+self.bounds.size.width*0.3;
    float startOfCircleY = self.bounds.origin.y+self.bounds.size.width*0.28;
    float centerOfCircleX = startOfCircleX+ RADIUS;
    float centerOfCircleY = startOfCircleY+ RADIUS;
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, 1.0);
    CGContextSetStrokeColorWithColor(context, currentColor.CGColor);
    CGContextBeginPath(context);
    
    //draw circle
    CGRect circleRect = CGRectMake(startOfCircleX, startOfCircleY, 2*RADIUS, 2*RADIUS);
    CGContextAddEllipseInRect(context, circleRect);
    
    CGFloat red,green,blue, talpha;
    [currentColor getRed:&red green:&green blue:&blue alpha:&talpha];

    CGContextSetRGBFillColor(context, red, green, blue, talpha);
    
    //draw triangle
    CGContextMoveToPoint(context, centerOfCircleX-0.35*RADIUS, centerOfCircleY+0.97*RADIUS);
    CGContextAddLineToPoint(context, centerOfCircleX - 1.6*RADIUS, centerOfCircleY);
    CGContextAddLineToPoint(context, centerOfCircleX-0.35*RADIUS, centerOfCircleY-0.97*RADIUS);
    CGContextMoveToPoint(context, centerOfCircleX-0.35*RADIUS, centerOfCircleY+0.97*RADIUS);
    CGContextSetRGBFillColor(context, red, green, blue, talpha);
    
    CGContextFillPath(context);
    CGContextStrokePath(context);
}


@end
