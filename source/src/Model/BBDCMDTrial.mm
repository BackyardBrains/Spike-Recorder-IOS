//
//  BBDCMDTrial.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/5/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "BBDCMDTrial.h"
#import "BBChannel.h"
@implementation BBDCMDTrial

@synthesize size;
@synthesize velocity;
@synthesize file=_file;
@synthesize distance;
@synthesize timeOfImpact;
@synthesize startOfRecording;

-(id) initWithSize:(float) inSize velocity:(float) inVelocity andDistance:(float) inDistance
{
    if(self = [super init])
    {
        self.size = inSize;
        self.velocity = inVelocity;
        self.file = nil;//[[BBFile allObjects] objectAtIndex:0];
        self.distance = inDistance;
        self.timeOfImpact = 0.0;//This should be calculated when we get experiment start time
        self.startOfRecording = 0.0;
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


- (NSDictionary *) createTrialDictionary
{
    NSMutableArray * tempAngles = [[[NSMutableArray alloc] initWithCapacity:0] autorelease];
    NSMutableArray * tempTimestamps = [[[NSMutableArray alloc] initWithCapacity:0] autorelease];
    for(int i = 0;i<[_angles count];i+=2)
    {
        [tempAngles addObject:(NSNumber *)[_angles objectAtIndex:i]];
        [tempTimestamps addObject:(NSNumber *)[_angles objectAtIndex:i+1]];
    }
    BBChannel * tempChannel = (BBChannel *)[_file.allChannels objectAtIndex:0];
    BBSpikeTrain * tempSpikestrain = (BBSpikeTrain *)[[tempChannel spikeTrains] objectAtIndex:0];
    NSArray * tempSpikeTimestamps = [tempSpikestrain makeArrayOfTimestampsWithOffset:startOfRecording];
    NSDictionary * returnDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:size],@"size",
     [NSNumber numberWithFloat:velocity], @"velocity",
     [NSNumber numberWithFloat:distance], @"distance",
     [NSNumber numberWithFloat:timeOfImpact], @"timeOfImpact",
     [NSNumber numberWithFloat:startOfRecording], @"startOfRecording",
     [tempAngles copy], @"angles",
     [tempTimestamps copy], @"timestamps",
     _file.filename, @"filename",
     tempSpikeTimestamps, @"spikeTimestamps",
     nil] ;
    return returnDict;
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
