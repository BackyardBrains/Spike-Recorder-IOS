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
	NSMutableArray *spikesCSV;
	NSString *comment;
	NSDate *date;
	NSMutableArray *_spikes;
    BOOL analyzed;
    NSString *spikesFiltered;
    NSMutableArray * _thresholds;
    NSInteger _currentSpikeTrain;
	float samplingrate;
	float gain;
	float filelength;
    
}

@property (nonatomic, retain) NSString *filename;
@property (nonatomic, retain) NSString *shortname;
@property (nonatomic, retain) NSString *subname;
@property (nonatomic, retain) NSString *comment;
@property (nonatomic, retain) NSMutableArray *spikesCSV;
@property (nonatomic, retain) NSDate *date;
@property (nonatomic, retain) NSMutableArray *spikes;
@property (nonatomic, retain) NSString *spikesFiltered;
@property BOOL analyzed;

@property (nonatomic) float thresholdFirst;
@property (nonatomic) float thresholdSecond;
@property (nonatomic, retain) NSMutableArray * thresholds;
@property (nonatomic) NSInteger currentSpikeTrain;
-(int) numberOfThresholds;
-(void) addAnotherThresholds;
-(NSInteger) moveToNextSpikeTrain;
-(void) removeCurrentThresholds;

@property float samplingrate;
@property float gain;
@property float filelength;

- (NSURL *)fileURL;
-(id) initWithUrl:(NSURL *) urlOfExistingFile;
-(id) initWav;
-(void) saveWithoutArrays;


@end
