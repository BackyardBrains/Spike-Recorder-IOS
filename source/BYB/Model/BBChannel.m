//
//  BBChannel.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 6/14/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "BBChannel.h"
#define kSpikeTrains @"spikeTrainsArray"
#define kNameOfChannel @"channelName"


@implementation BBChannel

@synthesize nameOfChannel = _nameOfChannel;
@synthesize spikeTrains = _spikeTrains;


-(id) initWithNameOfChannel:(NSString *) newName
{
    if ((self = [super init])) {
        _nameOfChannel = [newName copy];
        _spikeTrains = [[NSMutableArray alloc] init];
    }
    return self;
}

-(void) setSpikeTrains:(NSMutableArray *) inSpikeTrains
{
    [_spikeTrains removeAllObjects];
    [_spikeTrains addObjectsFromArray:inSpikeTrains];
}

-(NSMutableArray*) spikeTrains
{
    return _spikeTrains;
}

- (void) encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:_nameOfChannel forKey:kNameOfChannel];
    [encoder encodeObject:_spikeTrains forKey:kSpikeTrains];
}

- (id)initWithCoder:(NSCoder *)decoder {
    NSString * newNameOfChannel = [decoder decodeObjectForKey:kNameOfChannel];
    BBChannel* tempSelf = [self initWithNameOfChannel:newNameOfChannel];
    [self setSpikeTrains:[decoder decodeObjectForKey:kSpikeTrains]];

    return tempSelf;
}

- (void)dealloc {
    
    [_spikeTrains release];
	[super dealloc];
    
}

@end
