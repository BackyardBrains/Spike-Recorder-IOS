//
//  BBEvent.m
//  Spike Recorder
//
//  Created by Stanislav on 6/20/19.
//  Copyright © 2019 BackyardBrains. All rights reserved.
//

#import "BBEvent.h"
#define kValueTitle @"eventvalue"
#define kIndexTitle @"eventindex"
#define kTimeTitle @"eventtime"
@implementation BBEvent

@synthesize value;
@synthesize index;
@synthesize time;

-(id) initWithValue:(int) inValue index:(int) inIndex andTime:(float) inTime
{
    if ((self = [super init])) {
        value = inValue;
        index = inIndex;
        time = inTime;
    }
    return self;
}


- (void) encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeInt:index forKey:kIndexTitle];
    [encoder encodeInt:value forKey:kValueTitle];
    [encoder encodeFloat:time forKey:kTimeTitle];
}

- (id)initWithCoder:(NSCoder *)decoder {
    int someIndex = [decoder decodeIntForKey:kIndexTitle];
    int someValue = [decoder decodeIntForKey:kValueTitle];
    float someTime = [decoder decodeFloatForKey:kTimeTitle];
    return [self initWithValue:someValue index:someIndex andTime:someTime];
}

- (void)dealloc {
    
    [super dealloc];
}


@end

