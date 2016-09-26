//
//  BBDCMDExperiment.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/5/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "BBDCMDExperiment.h"
#import "BBDCMDTrial.h"
#import "BBChannel.h"

@implementation BBDCMDExperiment

@synthesize name;
@synthesize comment;
@synthesize date;
@synthesize distance;
@synthesize numberOfTrialsPerPair;
@synthesize delayBetweenTrials;
@synthesize contrast;
@synthesize typeOfStimulus;
@synthesize color;
@synthesize file;


- (id)init{
	if ((self = [super init])) {
		self.name = @"Experiment";
		self.comment = @"Your comment here";
        self.date = [NSDate date];
        self.distance = 0.09;
        self.numberOfTrialsPerPair = 5;
        self.delayBetweenTrials = 25.0;
        self.file = nil;
        self.contrast = 100;//percentage
        self.typeOfStimulus = 1;//Type of stimulus 1 - circle, 2 - ?
        _velocities = [[NSMutableArray alloc] initWithCapacity:0];
        [_velocities addObject:[NSNumber numberWithFloat:-2.0f]];
        [_velocities addObject:[NSNumber numberWithFloat:-6.0f]];
        [_velocities addObject:[NSNumber numberWithFloat:-10.0f]];
        _sizes = [[NSMutableArray alloc] initWithCapacity:0];
        [_sizes addObject:[NSNumber numberWithFloat:0.14f]];
        _trials = [[NSMutableArray alloc] initWithCapacity:0];
        _color =  [[NSMutableArray alloc] initWithCapacity:0];
        [_color addObject:@"000000"];
    }
    
	return self;
}



#pragma mark - Setters

-(void) setVelocities:(NSMutableArray *)inVelocities
{
    [_velocities removeAllObjects];
    [_velocities addObjectsFromArray:inVelocities];
}

-(void) setColor:(NSMutableArray *)inColor
{
    [_color removeAllObjects];
    [_color addObjectsFromArray:inColor];
}

-(NSMutableArray *) color
{
    return _color;
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
        [tempTrials addObject:[((BBDCMDTrial *)[_trials objectAtIndex:i]) createTrialDictionaryWithVersion:NO]];
    }
    
    
    
    NSMutableDictionary * retDic = [[NSMutableDictionary alloc] initWithCapacity:0];
    
    
    NSDictionary * returnDict = [NSDictionary dictionaryWithObjectsAndKeys:name,@"name",
                                  comment, @"comment",
                                  [NSNumber numberWithFloat:distance], @"displayDistance",
                                  [tempTrials copy], @"trials",
                                  [_velocities copy], @"velocities",
                                  [_sizes copy], @"objectSizes",
                                  _file.filename, @"filename",
                                  [NSNumber numberWithInt:numberOfTrialsPerPair], @"trialsPerPair",
                                  [NSNumber numberWithFloat:delayBetweenTrials], @"delayBetweenTrials",
                                  
                                  nil] ;
    BBDCMDTrial * tempFirstTrial = (BBDCMDTrial *)[_trials objectAtIndex:0];
    BBFile * tempFile = [tempFirstTrial file];
    BBChannel * tempChannel = (BBChannel *)[tempFile.allChannels objectAtIndex:0];
    BBSpikeTrain * tempSpikestrain = (BBSpikeTrain *)[[tempChannel spikeTrains] objectAtIndex:0];
    NSMutableArray * tempSpikeTimestamps = [[NSMutableArray alloc] initWithArray:[tempSpikestrain makeArrayOfTimestampsWithOffset:0]];

    NSDictionary * timestampsDict = [NSDictionary dictionaryWithObjectsAndKeys:tempSpikeTimestamps,@"allSpikesTimestamps",
                                 nil] ;

    [retDic addEntriesFromDictionary:returnDict];
    [retDic setValue:JSON_VERSION forKey:@"jsonversion"];
    [retDic setValue:[tempFile filename] forKey:@"filename"];
    [retDic setValue:timestampsDict forKey: @"timestamps"];
    return [NSDictionary dictionaryWithDictionary:retDic];
}

- (void)dealloc {
	[name release];
	[comment release];
    [color release];
    [date release];
	
	[_velocities release];
    [_sizes release];
    [_trials release];
    
   
    
	[super dealloc];
}


@end
