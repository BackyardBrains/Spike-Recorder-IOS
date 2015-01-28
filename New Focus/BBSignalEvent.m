//
//  BBSignalEvent.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 6/14/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "BBSignalEvent.h"
#define kTypeTitle @"eventtype"
#define kIndexTitle @"eventindex"
#define kTimeTitle @"eventtime"

@implementation BBSignalEvent

@synthesize eventType;
@synthesize index;
@synthesize time;

-(id) initWithType:(int) inType index:(int) inIndex andTime:(float) inTime
{
    if ((self = [super init])) {
        eventType = inType;
        index = inIndex;
        time = inTime;
    }
    return self;
}


- (void) encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeInt:index forKey:kIndexTitle];
    [encoder encodeInt:eventType forKey:kTypeTitle];
    [encoder encodeFloat:time forKey:kTimeTitle];
}

- (id)initWithCoder:(NSCoder *)decoder {
    int someIndex = [decoder decodeIntForKey:kIndexTitle];
    int someType = [decoder decodeIntForKey:kTypeTitle];
    float someTime = [decoder decodeFloatForKey:kTimeTitle];
    return [self initWithType:someType index:someIndex andTime:someTime];
}



@end
