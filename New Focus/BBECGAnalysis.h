//
//  BBECGAnalysis.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 9/14/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NVDSP.h"
#import "NVHighpassFilter.h"
#import "NVLowpassFilter.h"
#import <Accelerate/Accelerate.h>
#define HEART_BEAT_NOTIFICATION @"heartBeatNotification"


@interface BBECGAnalysis : NSObject
{
    NVHighpassFilter * HPF;
    NVLowpassFilter * LPF;
    NVLowpassFilter * LPF2;
    float * singleChannelBuffer;
    UInt32 numberOfChannels;
    float channelSamplingRate;
    float maxValueForECG;
    float currentTimeECG;
    float threshold;
    int numberOfPeaksDetected;
    float lastSampleECG;
    
    float lastTimePeak;
    float secondLastTimePeak;
    float thirdLastTimePeak;
    float * bufferForDiff;
    float valueToKeepForDiff;
}

@property (readonly) float heartRate;
@property (readonly) BOOL heartBeatPresent;


-(void) initECGAnalysisWithSamplingRate:(float) samplingRate numOfChannels:(UInt32) numOfChannels;
-(void) calculateECGAnalysis:(float *) newData numberOfFrames:(UInt32) numOfFrames selectedChannel:(UInt32) selectedChannel;

@end


