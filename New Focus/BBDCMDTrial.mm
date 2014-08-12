//
//  BBDCMDTrial.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/5/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "BBDCMDTrial.h"

@implementation BBDCMDTrial

@synthesize size;
@synthesize velocity;
@synthesize file=_file;
@synthesize distance;
@synthesize timeOfImpact;

-(id) initWithSize:(float) inSize velocity:(float) inVelocity andDistance:(float) inDistance
{
    if(self = [super init])
    {
        self.size = inSize;
        self.velocity = inVelocity;
        self.file = nil;//[[BBFile allObjects] objectAtIndex:0];
        self.distance = inDistance;
        self.timeOfImpact = 0.0;//This should be calculated when we get experiment start time
        _angles = [[NSMutableArray  alloc] initWithCapacity:0];
    }
    return self;
}



#pragma mark - Setters
//
//interlived format timestamp, angle
//
-(void) setAngles:(NSMutableArray *) inAngles
{
    if(_angles==nil)
    {
        _angles = [[NSMutableArray  alloc] initWithCapacity:0];
    }
    [_angles removeAllObjects];
    [_angles addObjectsFromArray:inAngles];
}

-(NSMutableArray *) angles
{
    return _angles;
}

- (void)dealloc {
	[_file release];
	[_angles release];
    
    [super dealloc];
}

@end
