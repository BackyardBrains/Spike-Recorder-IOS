//
//  BBFileTableCell.m
//  Backyard Brains
//
//  Created by Alex Wiltschko on 3/9/10.
//  Copyright 2010 University of Michigan. All rights reserved.
//

#import "BBFileTableCell.h"


@implementation BBFileTableCell

@synthesize shortname       = _shortname;
@synthesize subname         = _subname;
@synthesize lengthname      = _lengthname;

- (void)dealloc
{
    [_shortname release];
    [_subname release];
    [_lengthname release];
    [super dealloc];
}



@end
