//
//  BBDCMDTrial.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/5/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "BBDCMDTrial.h"
#import "BBChannel.h"
#import "BBAnalysisManager.h"
#import "BBSpike.h"

@implementation BBDCMDTrial

@synthesize size;
@synthesize velocity;
@synthesize file=_file;
@synthesize distance;
@synthesize timeOfImpact;
@synthesize startOfTrialTimestamp;
@synthesize color;

-(id) initWithSize:(float) inSize velocity:(float) inVelocity andDistance:(float) inDistance
{
    if(self = [super init])
    {
        self.size = inSize;
        self.velocity = inVelocity;
        self.file = nil;//[[BBFile allObjects] objectAtIndex:0];
        self.distance = inDistance;
        self.timeOfImpact = 0.0;//This should be calculated when we get experiment start time
        self.startOfTrialTimestamp = 0.0;
        _angles = [[NSMutableArray  alloc] initWithCapacity:0];
        self.color = @"000000";
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


- (NSDictionary *) createTrialDictionaryWithVersion:(BOOL) addVersion
{
    NSMutableArray * tempAngles = [[[NSMutableArray alloc] initWithCapacity:0] autorelease];
    NSMutableArray * tempTimestamps = [[[NSMutableArray alloc] initWithCapacity:0] autorelease];
    float tempTimestamp;
    for(int i = 0;i<[_angles count];i+=2)
    {
        [tempAngles addObject:(NSNumber *)[_angles objectAtIndex:i]];
        tempTimestamp = [(NSNumber *)[_angles objectAtIndex:i+1] floatValue]+startOfTrialTimestamp;
        [tempTimestamps addObject:[NSNumber numberWithFloat: tempTimestamp]];
    }
    /*[[BBAnalysisManager bbAnalysisManager] findSpikes:_file];
    
    NSMutableArray * tempSpikeTimestamps = [[[NSMutableArray alloc] initWithCapacity:0] autorelease];
    for(int i=0;i<[[[_file allSpikes] objectAtIndex:0] count];i++)
    {
        [tempSpikeTimestamps addObject:[NSNumber numberWithFloat:[(BBSpike *)[[[_file allSpikes] objectAtIndex:0] objectAtIndex:i] time]]];
    }*/

    BBChannel * tempChannel = (BBChannel *)[_file.allChannels objectAtIndex:0];
    BBSpikeTrain * tempSpikestrain = (BBSpikeTrain *)[[tempChannel spikeTrains] objectAtIndex:0];
    NSMutableArray * tempSpikeTimestamps = [[NSMutableArray alloc] initWithArray:[tempSpikestrain makeArrayOfTimestampsWithOffset:0]];
    
 
    
    for(int spikeIndex = [tempSpikeTimestamps count]-1;spikeIndex>=0;spikeIndex--)
    {
        if([[tempSpikeTimestamps objectAtIndex:spikeIndex] floatValue] <startOfTrialTimestamp || [[tempSpikeTimestamps objectAtIndex:spikeIndex] floatValue] >[[tempTimestamps objectAtIndex:([tempTimestamps count]-1)] floatValue])
        {
            [tempSpikeTimestamps removeObjectAtIndex:spikeIndex];
        }
    }
    
    NSDictionary * returnDict;
    NSMutableDictionary * retDic = [[NSMutableDictionary alloc] initWithCapacity:0];
    if(addVersion)
    {

        returnDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:size],@"size",
                      [NSNumber numberWithFloat:velocity], @"velocity",
                      [NSNumber numberWithFloat:distance], @"distance",
                      [NSNumber numberWithFloat:timeOfImpact+startOfTrialTimestamp], @"timeOfImpact",
                      [NSNumber numberWithFloat:startOfTrialTimestamp], @"startOfTrial",
                      [tempAngles copy], @"angles",
                      [tempTimestamps copy], @"timestamps",
                      _file.filename, @"filename",
                      tempSpikeTimestamps, @"spikeTimestamps",
                      nil] ;
        [retDic addEntriesFromDictionary:returnDict];
        [retDic setValue:JSON_VERSION forKey:@"jsonversion"];
        [retDic setValue:color forKey:@"color"];
        return [NSDictionary dictionaryWithDictionary:retDic];
        
    }
    else
    {
        returnDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:size],@"size",
                      [NSNumber numberWithFloat:velocity], @"velocity",
                      [NSNumber numberWithFloat:distance], @"distance",
                      [NSNumber numberWithFloat:timeOfImpact+startOfTrialTimestamp], @"timeOfImpact",
                      [NSNumber numberWithFloat:startOfTrialTimestamp], @"startOfTrial",
                      [tempAngles copy], @"angles",
                      [tempTimestamps copy], @"timestamps",
                      _file.filename, @"filename",
                      tempSpikeTimestamps, @"spikeTimestamps",
                      nil] ;
        [retDic addEntriesFromDictionary:returnDict];
        [retDic setValue:color forKey:@"color"];
        return [NSDictionary dictionaryWithDictionary:retDic];
    
    }
    
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
