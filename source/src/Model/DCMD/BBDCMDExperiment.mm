//
//  BBDCMDExperiment.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/5/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "BBDCMDExperiment.h"
#import "BBDCMDTrial.h"
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
        self.distance = 0.09;
        self.numberOfTrialsPerPair = 5;
        self.delayBetweenTrials = 40.0;
        self.contrast = 100;//percentage
        self.typeOfStimulus = 1;//Type of stimulus 1 - circle, 2 - ?
        _velocities = [[NSMutableArray alloc] initWithCapacity:0];
        [_velocities addObject:[NSNumber numberWithFloat:-3.0f]];
        [_velocities addObject:[NSNumber numberWithFloat:-2.0f]];
        [_velocities addObject:[NSNumber numberWithFloat:-4.0f]];
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


-(NSDictionary *) createExperimentDictionary
{
    NSMutableArray * tempTrials = [[[NSMutableArray alloc] initWithCapacity:0] autorelease];
    for(int i=0;i<[_trials count];i++)
    {
        [tempTrials addObject:[((BBDCMDTrial *)[_trials objectAtIndex:i]) createTrialDictionary]];
    }
    
    NSDictionary * returnDict = [NSDictionary dictionaryWithObjectsAndKeys:name,@"name",
                                  comment, @"comment",
                                  [NSNumber numberWithFloat:distance], @"distance",
                                  [tempTrials copy], @"trials",
                                  [_velocities copy], @"velocities",
                                  [_sizes copy], @"sizes",
                                  [NSNumber numberWithInt:numberOfTrialsPerPair], @"trialsPerPair",
                                  [NSNumber numberWithFloat:delayBetweenTrials], @"delayBetweenTrials",
                                  nil] ;
    return returnDict;
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
