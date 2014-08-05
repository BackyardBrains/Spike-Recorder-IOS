//
//  BBSpikeTrain.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 6/13/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SQLitePersistentObject.h"

@interface BBSpikeTrain : NSObject <NSCoding>

@property (nonatomic, retain) NSString * nameOfTrain;//name of spike train
@property (nonatomic, retain) NSMutableArray * spikes;//spikes as array of BBSpike objects
@property (nonatomic, retain) NSString * spikesCSV;//spikes in SCV string form
@property float firstThreshold;
@property float secondThreshold;

-(id) initWithName:(NSString *) inName;
-(void) spikesToCSV;
-(void) CSVToSpikes;
@end
