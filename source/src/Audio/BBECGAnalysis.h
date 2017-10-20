//
//  BBECGAnalysis.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 9/14/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NVDSP.h"
#import <Accelerate/Accelerate.h>
#define HEART_BEAT_NOTIFICATION @"heartBeatNotification"

#define NUMBER_OF_BEATS_TO_REMEMBER 100
#define NUMBER_OF_SEC_TO_AVERAGE 6


@interface BBECGAnalysis : NSObject
{
    
    float * beatTimestamps;
    UInt32 numberOfChannels;
    float channelSamplingRate;
    UInt32 updateECGWithNumberOfFrames;
    int currentBeatIndex;
    int beatsCollected;
    float lastTime;
}

@property (readonly) float heartRate;



-(void) reset;


-(void) initECGAnalysisWithSamplingRate:(float) samplingRate numOfChannels:(UInt32) numOfChannels;
-(void) updateECGData:(float * ) data withNumberOfFrames:(UInt32) numberOfFrames numberOfChannels: (int)numOfChannels andThreshold:(float) threshold;
@end


