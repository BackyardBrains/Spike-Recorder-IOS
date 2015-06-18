//
//  BBFile.h
//  Backyard Brains
//
//  Created by Alex Wiltschko on 2/21/10.
//  Copyright 2010 University of Michigan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "SQLitePersistentObject.h"
#import "BBAudioManager.h"
#import "BBSpikeTrain.h"

#define FILE_SPIKE_SORTED @"filtered"
#define FILE_NOT_SPIKE_SORTED @"notAnalized"

#define NORMAL_FILE_USAGE 0
#define EXPERIMENT_FILE_USAGE 2


@interface BBFile : SQLitePersistentObject {
	NSString *filename;
	NSString *shortname;
	NSString *subname;

	NSString *comment;
	NSDate *date;
	float samplingrate;
	float gain;
	float filelength;
    int numberOfChannels;
    int fileUsage;
    
	NSMutableArray *_allSpikes;
    NSMutableArray *_allChannels;
    NSMutableArray *_allEvents;
    NSString *spikesFiltered;
}

@property (nonatomic, retain) NSString *filename;
@property (nonatomic, retain) NSString *shortname;
@property (nonatomic, retain) NSString *subname;
@property (nonatomic, retain) NSString *comment;
@property (nonatomic, retain) NSDate *date;
@property float samplingrate;
@property float gain;
@property float filelength;
@property int numberOfChannels;
@property int fileUsage;

@property (nonatomic, retain) NSMutableArray *allSpikes; //array of spike arrays (for every channel)
@property (nonatomic, retain) NSMutableArray *allChannels; //array of BBChannel objects
@property (nonatomic, retain) NSMutableArray *allEvents;
@property (nonatomic, retain) NSString *spikesFiltered; //Flag string FILE_SPIKE_SORTED/FILE_NOT_SPIKE_SORTED


- (NSURL *)fileURL;
-(id) initWithUrl:(NSURL *) urlOfExistingFile;
-(id) initWav;
-(void) saveWithoutArrays;

-(NSURL *) prepareBYBFile;

-(int) numberOfSpikeTrains;
-(void) setupChannels;
-(BBSpikeTrain *) getSpikeTrainWithIndex:(int) spikeTrainIndex;
-(NSInteger) getChannelIndexForSpikeTrainWithIndex: (int) spikeTrainIndex;
-(NSInteger) getIndexInsideChannelForSpikeTrainWithIndex: (int) spikeTrainIndex;

@end
