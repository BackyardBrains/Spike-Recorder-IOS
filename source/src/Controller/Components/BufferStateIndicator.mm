//
//  BufferStateIndicator.m
//  Spike Recorder
//
//  Created by Stanislav Mircic on 2/25/15.
//  Copyright (c) 2015 Datta Lab, Harvard University. All rights reserved.
//

#import "BufferStateIndicator.h"
#define WIDTH_OF_INDICATOR 7.0
#define HEIGHT_OF_INDICATOR 20.0
@implementation BufferStateIndicator


- (void)drawRect:(CGRect)rect {
    stateOfBuffer = stateOfBuffer<0.0f?0.0f:stateOfBuffer;
    stateOfBuffer = stateOfBuffer>1.0f?1.0f:stateOfBuffer;
    
    float leftX= self.bounds.origin.x+self.bounds.size.width*0.5 - 0.5* WIDTH_OF_INDICATOR;
   // float rightX = self.bounds.origin.x+self.bounds.size.width*0.5 + 0.5 * WIDTH_OF_INDICATOR;
    float topY = self.bounds.origin.y+self.bounds.size.height*0.5 - HEIGHT_OF_INDICATOR*0.5;
   // float bottomY = self.bounds.origin.y+self.bounds.size.height*0.5 + HEIGHT_OF_INDICATOR*0.5;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, 1.0);
    CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextBeginPath(context);
    //CGFloat red,green,blue, talpha;
    //[currentColor getRed:&red green:&green blue:&blue alpha:&talpha];
    
    CGContextSetRGBFillColor(context, 0.0f, 0.0f, 0.0f, 1.0f);
    
    //draw background
    CGRect backgroundRect = CGRectMake(leftX, topY, WIDTH_OF_INDICATOR, HEIGHT_OF_INDICATOR);
    /*CGContextAddRect(context, backgroundRect);
    CGContextFillPath(context);
    */
    
    //draw frame
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetRGBFillColor(context, 0.0f, 0.0f, 0.0f, 1.0f);
    CGContextAddRect(context, backgroundRect);
    CGContextStrokePath(context);
    CGContextFillPath(context);
    
    //draw  buffer state
    float heightOfBuffer = HEIGHT_OF_INDICATOR * stateOfBuffer;
    CGRect bufferRect = CGRectMake(leftX, topY+(HEIGHT_OF_INDICATOR - heightOfBuffer), WIDTH_OF_INDICATOR, heightOfBuffer);
    
    //set color of buffer bar
    if(stateOfBuffer>0.55)
    {
        CGContextSetStrokeColorWithColor(context, [UIColor greenColor].CGColor);
        CGFloat red,green,blue, talpha;
        [[UIColor greenColor] getRed:&red green:&green blue:&blue alpha:&talpha];
        
        CGContextSetRGBFillColor(context, red, green, blue, 1.0);
    }
    else if(stateOfBuffer>0.25)
    {
        CGContextSetStrokeColorWithColor(context, [UIColor orangeColor].CGColor);
        CGFloat red,green,blue, talpha;
        [[UIColor orangeColor] getRed:&red green:&green blue:&blue alpha:&talpha];
        
        CGContextSetRGBFillColor(context, red, green, blue, 1.0);
    }
    else
    {
        CGContextSetStrokeColorWithColor(context, [UIColor redColor].CGColor);
        CGFloat red,green,blue, talpha;
        [[UIColor redColor] getRed:&red green:&green blue:&blue alpha:&talpha];
        
        CGContextSetRGBFillColor(context, red, green, blue, 1.0);
    }
    //draw buffer bar

    CGContextAddRect(context, bufferRect);
    
    CGContextFillPath(context);
    CGContextStrokePath(context);
    
}


-(void) updateBufferState:(float) bufferState
{
    stateOfBuffer = bufferState;
    [self setNeedsDisplay];
}

@end
