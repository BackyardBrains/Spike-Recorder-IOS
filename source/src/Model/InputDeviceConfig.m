//
//  InputDeviceConfig.m
//  Spike Recorder
//
//  Created by Stanislav on 03/05/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import "InputDeviceConfig.h"

@implementation InputDeviceConfig
@synthesize expansionBoards;
@synthesize channels;
@synthesize filterSettings;
@synthesize hardwareComProtocolType;
@synthesize connectedExpansionBoard;
- (id)init {
    if ((self = [super init])) {
        expansionBoards = [[NSMutableArray alloc] initWithCapacity:0];
        channels = [[NSMutableArray alloc] initWithCapacity:0];
        filterSettings = [[FilterSettings alloc] initWithTypicalValuesForSignalType:customSignalType];
        connectedExpansionBoard = NULL;
    }
    
    return self;
}

-(BOOL) isBasedOnComProtocol:(NSString *) commProtocolToCheck
{
    return !([hardwareComProtocolType rangeOfString:commProtocolToCheck].location == NSNotFound);
}

- (void)dealloc
{
    [expansionBoards removeAllObjects];
    [channels removeAllObjects];
    [expansionBoards release];
    [channels release];
    [super dealloc];
}
@end
