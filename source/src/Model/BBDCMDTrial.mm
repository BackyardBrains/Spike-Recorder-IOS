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
#import "UIDeviceExt.h"

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
        //when we export just a trial we have to add JSON's version to JSON
        returnDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:size],@"size",
                      [NSNumber numberWithFloat:velocity], @"velocity",
                      [NSNumber numberWithFloat:distance], @"distance",
                      [NSNumber numberWithFloat:timeOfImpact+startOfTrialTimestamp], @"timeOfImpact",
                      [NSNumber numberWithFloat:startOfTrialTimestamp], @"startOfTrial",
                      [tempAngles copy], @"objectAngles",
                      [tempTimestamps copy], @"angleTimestamps",
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
    
        CGRect screenBounds = [[UIScreen mainScreen] bounds] ;//[[UIScreen mainScreen] bounds];
        
        CGFloat screenScale = [[UIScreen mainScreen] scale];
        CGSize screenSize = CGSizeMake(screenBounds.size.width * screenScale, screenBounds.size.height * screenScale);
        float pixelsPerMeter = [UIDeviceExt pixelsPerCentimeter] * 100.0f;
        float screenWidthInPixels;
        float screenHeightInPixels;
        if(screenSize.width>screenSize.height)
        {
            screenHeightInPixels = screenSize.width;
            screenWidthInPixels = screenSize.height;
        }
        else
        {
            screenHeightInPixels = screenSize.height;
            screenWidthInPixels = screenSize.width;
        }
        float screenDiagonalInPixels = sqrtf(screenWidthInPixels*screenWidthInPixels+screenHeightInPixels*screenHeightInPixels);
        
        float iosDeviceShortSize = (screenWidthInPixels*0.5)/pixelsPerMeter;
        float iosDeviceLongSize = (screenHeightInPixels*0.5)/pixelsPerMeter;
        float iosDeviceDiagSize = (screenDiagonalInPixels*0.5)/pixelsPerMeter;
        
        float theta0 =[[tempAngles objectAtIndex:0] floatValue];
        
        float d0 = (size*0.5)/tanf(theta0);
        float t0 = [[tempTimestamps objectAtIndex:0] floatValue];
        
        float tImpactShort = t0+((distance*((size*0.5)/iosDeviceShortSize) - d0)/ velocity);
        float tImpactLong = t0+((distance*((size*0.5)/iosDeviceLongSize) - d0)/ velocity);
        float tImpactDiag = t0+((distance*((size*0.5)/iosDeviceDiagSize) - d0)/ velocity);
        
       
        NSDictionary * timestampsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:timeOfImpact+startOfTrialTimestamp], @"timeOfImpact",
                                               [tempTimestamps objectAtIndex:0],@"objectAppears",
                                               [NSNumber numberWithFloat:tImpactShort], @"objectFillWidth",
                                               [NSNumber numberWithFloat:tImpactLong], @"objectFillHeight",
                                               [NSNumber numberWithFloat:tImpactDiag], @"objectFillDiag",
                                               [tempTimestamps objectAtIndex:([tempTimestamps count]-1)],@"objectDisappears",
                                               [NSNumber numberWithFloat:startOfTrialTimestamp], @"startOfTrial",
                                               [tempTimestamps copy], @"angleTimestamps",
                                               nil] ;
        
        returnDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:size],@"objectSize",
                      [NSNumber numberWithFloat:velocity], @"velocity",
                      [tempAngles copy], @"objectAngles",
                      _file.filename, @"filename",
                      [timestampsDictionary copy], @"timestamps",
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
