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
- (id)init {
    if ((self = [super init])) {
        expansionBoards = [[NSMutableArray alloc] initWithCapacity:0];
        channels = [[NSMutableArray alloc] initWithCapacity:0];
        filterSettings = [[FilterSettings alloc] initWithTypicalValuesForSignalType:customSignalType];
    }
    
    return self;
}
@end
