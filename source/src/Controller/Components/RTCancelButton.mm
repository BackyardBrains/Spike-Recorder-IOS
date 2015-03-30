//
//  RTCancelButton.m
//  Spike Recorder
//
//  Created by Stanislav Mircic on 3/17/15.
//  Copyright (c) 2015 Datta Lab, Harvard University. All rights reserved.
//

#import "RTCancelButton.h"
#import "BYBGLView.h"

@implementation RTCancelButton

-(void) objectColor:(UIColor * ) theColor
{
    currentColor = theColor;
    [self setNeedsDisplay];
}


- (void)drawRect:(CGRect)rect {
    if(currentColor == nil)
    {
        currentColor = [BYBGLView getSpikeTrainColorWithIndex:0 transparency:1.0f];
    }
    
    float leftX = self.bounds.origin.x+self.bounds.size.width*0.2;
    float rightX = self.bounds.origin.x+self.bounds.size.width*0.8;
    float topY = self.bounds.origin.y+self.bounds.size.height*0.3;
    float bottomY = self.bounds.origin.y+self.bounds.size.height*0.9;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, 4.0);
    CGContextSetStrokeColorWithColor(context, [UIColor redColor].CGColor);
    CGContextBeginPath(context);
    
    //draw X
    CGContextMoveToPoint(context, leftX,topY);
    CGContextAddLineToPoint(context, rightX,bottomY);
    CGContextMoveToPoint(context, leftX,bottomY);
    CGContextAddLineToPoint(context, rightX,topY);
    
    CGContextStrokePath(context);
}


@end
