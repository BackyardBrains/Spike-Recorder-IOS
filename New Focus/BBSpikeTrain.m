//
//  BBSpikeTrain.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 6/13/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "BBSpikeTrain.h"
#import "BBSpike.h"
#define kSpikesArray @"spikesarray"
#define kSpikesCSV @"spikesCSVString"
#define kFirstThreshold @"firstThreshold"
#define kSecondThreshold @"secondThreshold"
#define kNameOfTrain @"nameOfTrain"


@implementation BBSpikeTrain
@synthesize spikes;
@synthesize spikesCSV;
@synthesize firstThreshold;
@synthesize secondThreshold;
@synthesize nameOfTrain;

-(id) initWithName:(NSString *) inName
{
    if ((self = [super init])) {
        nameOfTrain = [inName copy];
        firstThreshold = 0.0f;
        secondThreshold = 0.0f;
        spikes = [[NSMutableArray alloc] init];
        self.spikesCSV = [NSString string];
    }
    return self;
}

-(void) setSpikes:(NSMutableArray *) inSpikes
{
    [spikes removeAllObjects];
    [spikes addObjectsFromArray:inSpikes];
}

-(NSMutableArray*) spikes
{
    return spikes;
}

- (void) encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeFloat:firstThreshold forKey:kFirstThreshold];
    [encoder encodeFloat:secondThreshold forKey:kSecondThreshold];
    [encoder encodeObject:spikesCSV forKey:kSpikesCSV];
    [encoder encodeObject:nameOfTrain forKey:kNameOfTrain];
    [encoder encodeObject:spikes forKey:kSpikesArray];
}

- (id)initWithCoder:(NSCoder *)decoder {
    NSString * newName = [decoder decodeObjectForKey:kNameOfTrain];
    [self initWithName:newName];
    self.secondThreshold = [decoder decodeFloatForKey:kSecondThreshold];
    self.firstThreshold = [decoder decodeFloatForKey:kFirstThreshold];
    [self setSpikes:[decoder decodeObjectForKey:kSpikesArray]];
    [self setSpikesCSV:[decoder decodeObjectForKey:kSpikesCSV]];

    [self CSVToSpikes];
    
    return self;
}

//
// Make array of CSV strings out of spike train
// We do this because it is much faster to save  long string
// than array with hundreds of spike objects
// When we load file object we "decompress" CSVs into array of spikes
//
-(void) spikesToCSV
{
    BBSpike * tempSpike;

    NSMutableString *csvString = [NSMutableString string];
    for(int i=0;i<[self.spikes count];i++)
    {
        tempSpike = (BBSpike *) [self.spikes objectAtIndex:i];
        [csvString appendString:[NSString stringWithFormat:@"%f,%f,%d\n",
                                 tempSpike.value, tempSpike.time, tempSpike.index]];
    }
    [self.spikes removeAllObjects];
    self.spikesCSV = csvString;
}


//
// Convert CSV strings to array of spike train 
//
-(void) CSVToSpikes
{
    [self.spikes removeAllObjects];
    NSMutableArray * newSpikeTrain = [[[NSMutableArray alloc] initWithCapacity:0] autorelease];
    NSScanner *scanner = [NSScanner scannerWithString:spikesCSV];
    [scanner setCharactersToBeSkipped:
     [NSCharacterSet characterSetWithCharactersInString:@"\n, "]];
    float value, time;
    int index;
    BBSpike * newSpike;
    while ( [scanner scanFloat:&value] && [scanner scanFloat:&time] && [scanner scanInt:&index]) {
        newSpike = [[BBSpike alloc] initWithValue:value index:index andTime:time];
        [newSpikeTrain addObject:newSpike];
        [newSpike release];
    }
    [self setSpikes:newSpikeTrain];
}

- (void)dealloc {
    
    [spikes release];
	[super dealloc];
}


@end
