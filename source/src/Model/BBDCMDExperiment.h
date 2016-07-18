//
//  BBDCMDExperiment.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/5/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "SQLitePersistentObject.h"

@interface BBDCMDExperiment : SQLitePersistentObject
{
    NSString *name;
	NSString *comment;
	NSDate *date;
    float distance;//distance to grasshopper in mm
    NSMutableArray * _velocities;
    NSMutableArray * _sizes;
    int numberOfTrialsPerPair;//Number of trials for every spped-size pair
    float delayBetweenTrials; //in seconds
    float contrast;//in percentage
    int typeOfStimulus;
    NSMutableArray * _trials;
}
@property (nonatomic,retain) NSString *name;
@property (nonatomic,retain) NSString *comment;
@property (nonatomic,retain) NSDate *date;
@property float distance;//distance to grasshopper
@property (nonatomic,retain) NSMutableArray * velocities;
@property (nonatomic,retain) NSMutableArray * sizes;
@property int numberOfTrialsPerPair;//Number of trials for every spped-size pair
@property float delayBetweenTrials;//in seconds
@property float contrast;//in percentage
@property int typeOfStimulus;
@property (nonatomic,retain) NSMutableArray * trials;
@property (nonatomic,retain) NSString *color;


-(NSDictionary *) createExperimentDictionary;

@end
