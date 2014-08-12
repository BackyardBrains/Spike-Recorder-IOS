//
//  BBDCMDExperiment.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/5/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "BBDCMDExperiment.h"

@implementation BBDCMDExperiment

@synthesize name;
@synthesize comment;
@synthesize date;
@synthesize distance;
@synthesize numberOfTrialsPerPair;
@synthesize delayBetweenTrials;
@synthesize contrast;
@synthesize typeOfStimulus;


- (id)init{
	if ((self = [super init])) {
		self.name = @"Experiment";
		self.comment = @"Your comment here";
        self.date = [NSDate date];
        self.distance = 0.15;
        self.numberOfTrialsPerPair = 5;
        self.delayBetweenTrials = 40.0;
        self.contrast = 100;//percentage
        self.typeOfStimulus = 1;//Type of stimulus 1 - circle, 2 - ?
        _velocities = [[NSMutableArray alloc] initWithCapacity:0];
        [_velocities addObject:[NSNumber numberWithFloat:-0.5f]];
        [_velocities addObject:[NSNumber numberWithFloat:-0.4f]];
        [_velocities addObject:[NSNumber numberWithFloat:-0.6f]];
        _sizes = [[NSMutableArray alloc] initWithCapacity:0];
        [_sizes addObject:[NSNumber numberWithFloat:0.06f]];
        [_sizes addObject:[NSNumber numberWithFloat:0.1f]];
        [_sizes addObject:[NSNumber numberWithFloat:0.14f]];
        _trials = [[NSMutableArray alloc] initWithCapacity:0];
    }
    
	return self;
}



#pragma mark - Setters

-(void) setVelocities:(NSMutableArray *)inVelocities
{
    [_velocities removeAllObjects];
    [_velocities addObjectsFromArray:inVelocities];
}

-(NSMutableArray *) velocities
{
    return _velocities;
}

-(void) setSizes:(NSMutableArray *)inSizes
{
    [_sizes removeAllObjects];
    [_sizes addObjectsFromArray:inSizes];
}

-(NSMutableArray *) sizes
{
    return _sizes;
}


-(void) setTrials:(NSMutableArray *)inTrials
{
    [_trials removeAllObjects];
    [_trials addObjectsFromArray:inTrials];
}

-(NSMutableArray *) trials
{
    return _trials;
}

- (void)dealloc {
	[name release];
	[comment release];
    [date release];
	
	[_velocities release];
    [_sizes release];
    [_trials release];
    
   
    
	[super dealloc];
}


@end
