//
//  BBChannel.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 6/14/14.
//  Copyright (c) 2014 Backyard Brains.
//

#import <Foundation/Foundation.h>
#import "SQLitePersistentObject.h"

@interface BBChannel : NSObject <NSCoding>
@property (nonatomic, retain) NSString * nameOfChannel;//name of channel
@property (nonatomic, retain) NSMutableArray * spikeTrains;//spike trains for this channel

-(id) initWithNameOfChannel:(NSString *) newName;
@end
