//
//  BBSpike.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/11/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "BBSpike.h"
#define kValueTitle @"spikevalue"
#define kIndexTitle @"spikeindex"
#define kTimeTitle @"spiketime"
@implementation BBSpike

@synthesize value;
@synthesize index;
@synthesize time;

-(id) initWithValue:(float) inValue index:(int) inIndex andTime:(float) inTime
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
    [encoder encodeFloat:value forKey:kValueTitle];
    [encoder encodeFloat:time forKey:kTimeTitle];
}

- (id)initWithCoder:(NSCoder *)decoder {
    int someIndex = [decoder decodeIntForKey:kIndexTitle];
    float someValue = [decoder decodeFloatForKey:kValueTitle];
    float someTime = [decoder decodeFloatForKey:kTimeTitle];
    return [self initWithValue:someValue index:someIndex andTime:someTime];
}

- (void)dealloc {

	[super dealloc];
    
}


@end
