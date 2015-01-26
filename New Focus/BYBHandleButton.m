//
//  BYBHandleButton.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 1/26/15.
//  Copyright (c) 2015 BackyardBrains. All rights reserved.
//

#import "BYBHandleButton.h"

@implementation BYBHandleButton


- (void)drawRect:(CGRect)rect {
    UIColor *currentColor = [UIColor redColor];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, 2.0);
    CGContextSetStrokeColorWithColor(context, currentColor.CGColor);
    CGContextBeginPath(context); // <---- this
    CGContextMoveToPoint(context, self.bounds.origin.x, self.bounds.origin.y);
    CGContextAddLineToPoint(context, self.bounds.origin.x + self.bounds.size.width, self.bounds.origin.y + self.bounds.size.height);
    CGContextStrokePath(context);
}


@end
