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

@interface BBFile : SQLitePersistentObject {
	NSString *filename;
	NSString *shortname;
	NSString *subname;
	NSString *spikesCSV;
	NSString *comment;
	NSDate *date;
	NSMutableArray *_spikes;
	NSMutableArray *_filteredSpikes;
    BOOL analyzed;
    BOOL spikesFiltered;
    float threshold1;
    float threshold2;
	float samplingrate;
	float gain;
	float filelength;
}

@property (nonatomic, retain) NSString *filename;
@property (nonatomic, retain) NSString *shortname;
@property (nonatomic, retain) NSString *subname;
@property (nonatomic, retain) NSString *comment;
@property (nonatomic, retain) NSString *spikesCSV;
@property (nonatomic, retain) NSDate *date;
@property (nonatomic, retain) NSMutableArray *spikes;
@property (nonatomic, retain) NSMutableArray *filteredSpikes;
@property BOOL analyzed;
@property BOOL spikesFiltered;
@property float threshold1;
@property float threshold2;
@property float samplingrate;
@property float gain;
@property float filelength;

- (NSURL *)fileURL;
-(id) initWithUrl:(NSURL *) urlOfExistingFile;

@end
