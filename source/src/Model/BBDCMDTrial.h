//
//  BBDCMDTrial.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/5/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "SQLitePersistentObject.h"
#import "BBFile.h"
#import "BBDCMDExperiment.h"
@interface BBDCMDTrial : SQLitePersistentObject
{
    float size;
    float velocity;
    BBFile * _file;
    NSMutableArray * _angles;
    float timeOfImpact;
    float startOfRecording;
    float distance;
}

@property float size;
@property float velocity;
@property float distance;
@property (nonatomic,retain) BBFile * file;
@property (nonatomic,retain) NSMutableArray * angles;//interlived format timestamp, angle
@property float timeOfImpact;
@property float startOfRecording;

-(id) initWithSize:(float) inSize velocity:(float) inVelocity andDistance:(float) inDistance;
- (NSDictionary *) createTrialDictionaryWithVersion:(BOOL)addVersion;
@end
