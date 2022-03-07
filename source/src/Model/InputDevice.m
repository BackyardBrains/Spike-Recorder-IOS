//
//  InputDevice.m
//  Spike Recorder
//
//  Created by Stanislav on 04/11/2020.
//  Copyright © 2020 BackyardBrains. All rights reserved.
//

#import "InputDevice.h"

@implementation InputDevice

@synthesize config;
@synthesize currentlyActive;
@synthesize uniqueInstanceID;
-(id) initWithConfig:(InputDeviceConfig *)inconfig {
    self = [super init];
    
    if(self != nil) {
        config = inconfig;
        currentlyActive = NO;
    }
    return self;
}

-(BOOL) isBasedOnCommunicationProtocol:(NSString*) protocolToCheck
{
    return [[self config] isBasedOnComProtocol:protocolToCheck];
}
@end
