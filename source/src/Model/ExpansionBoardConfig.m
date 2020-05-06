//
//  ExpansionBoardConfig.m
//  Spike Recorder
//
//  Created by Stanislav on 03/05/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import "ExpansionBoardConfig.h"

@implementation ExpansionBoardConfig
@synthesize channels;
- (id)init {
    if ((self = [super init])) {
        channels = [[NSMutableArray alloc] initWithCapacity:0];
        
        
    }
    
    return self;
}
@end
