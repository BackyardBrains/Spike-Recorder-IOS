//
//  RTSpikeSortingButton.m
//  Spike Recorder
//
//  Created by Stanislav Mircic on 3/17/15.
//  Copyright (c) 2015 Datta Lab, Harvard University. All rights reserved.
//

#import "RTSpikeSortingButton.h"
#import "BYBGLView.h"
#define RADIUS 11.0

@implementation RTSpikeSortingButton



-(void) objectColor:(UIColor * ) theColor
{
    currentColor = theColor;
    [self setNeedsDisplay];
}


-(void) changeCurrentState:(int) newCurrentState
{
    currentState = newCurrentState;
    [self setNeedsDisplay];
}

-(int) currentStatus
{
    return currentState;
}

- (void)drawRect:(CGRect)rect {

    currentColor = [BYBGLView getSpikeTrainColorWithIndex:4 transparency:1.0f];
    
    
    if(currentState == HANDLE_STATE)
    {
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
    else  //if we are in tick mark state
    {
        
        float startOfTickMarkX = self.bounds.origin.x+self.bounds.size.width*0.2;
        float startOfTickMarkY = self.bounds.origin.y+self.bounds.size.height*0.55;
        float bottomOfTickMarkX = self.bounds.origin.x+self.bounds.size.width*0.45;
        float bottomOfTickMarkY = self.bounds.origin.y+self.bounds.size.height*0.85;
        float topTickMarkX = self.bounds.origin.x+self.bounds.size.width*0.85;
        float topTickMarkY = self.bounds.origin.y+self.bounds.size.height*0.2;
        
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetLineWidth(context, 4.0);
        CGContextSetStrokeColorWithColor(context, [UIColor greenColor].CGColor);
        CGContextBeginPath(context);

        
        CGContextMoveToPoint(context, startOfTickMarkX, startOfTickMarkY);
        CGContextAddLineToPoint(context, bottomOfTickMarkX, bottomOfTickMarkY);
        CGContextAddLineToPoint(context, topTickMarkX, topTickMarkY);
        

        CGContextStrokePath(context);
    
    }
}


@end
