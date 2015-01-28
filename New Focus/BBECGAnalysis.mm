//
//  BBECGAnalysis.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 9/14/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "BBECGAnalysis.h"
#define MIN_PEAK_TIME 0.200 //200ms

@implementation BBECGAnalysis
@synthesize heartRate;
@synthesize heartBeatPresent;
@synthesize extThreshold;


-(void) initECGAnalysisWithSamplingRate:(float) samplingRate numOfChannels:(UInt32) numOfChannels
{
    
    numberOfChannels = numOfChannels;
    channelSamplingRate = samplingRate;
    //Filters for automatic heart rate detection
    LPF = [[NVLowpassFilter alloc] initWithSamplingRate:samplingRate];
    LPF.cornerFrequency = 80.0f;
    LPF.Q = 0.5f;
    
    HPF = [[NVHighpassFilter alloc] initWithSamplingRate:samplingRate];
    HPF.cornerFrequency = 30.0f;
    HPF.Q = 0.5f;
    
    LPF2 = [[NVLowpassFilter alloc] initWithSamplingRate:samplingRate];
    LPF2.cornerFrequency = 10.0f;
    LPF2.Q = 0.5f;
    
    
    singleChannelBuffer = (float *)calloc(1024, sizeof(float));
    bufferForDiff = (float *)calloc(1025, sizeof(float));
    maxValueForECG = 0.000001;
    currentTimeECG = 0.0f;
    threshold = 0.1;
    numberOfPeaksDetected = 0;
    lastSampleECG = 0.0f;
    heartBeatPresent = NO;
}

-(void) calculateECGWithThreshold:(float *) newData numberOfFrames:(UInt32) numOfFrames selectedChannel:(UInt32) selectedChannel
{
    float zero = 0.0f;
    //get selected channel
    vDSP_vsadd((float *)&newData[selectedChannel],
               numberOfChannels,
               &zero,
               singleChannelBuffer,
               1,
               numOfFrames);
    
    float oneSampleTime = (1.0f/channelSamplingRate);
    //find peaks
    for(int i=0;i<numOfFrames;i++)
    {
        if(lastSampleECG<extThreshold && singleChannelBuffer[i]>extThreshold && (currentTimeECG+ i*oneSampleTime -lastTimePeak)>MIN_PEAK_TIME)
        {
            //we jumped over threshold
            numberOfPeaksDetected++;
            if(numberOfPeaksDetected>3)
            {
                heartBeatPresent = YES;
                
                [[NSNotificationCenter defaultCenter] postNotificationName:HEART_BEAT_NOTIFICATION object:self];
                
                numberOfPeaksDetected = 4;
                //calculate average for last 3 peaks
                heartRate = ((secondLastTimePeak-thirdLastTimePeak)+(lastTimePeak-secondLastTimePeak)+((currentTimeECG+i*oneSampleTime)-lastTimePeak))/3.0f;
                heartRate = 60.0f/heartRate;
                //NSLog(@"%f",heartRate);
            }
            //refresh peaks
            thirdLastTimePeak = secondLastTimePeak;
            secondLastTimePeak = lastTimePeak;
            lastTimePeak = currentTimeECG+i*oneSampleTime;
            
        }
        lastSampleECG = singleChannelBuffer[i];
    }
    currentTimeECG+=numOfFrames*oneSampleTime;
    
    //if we didn't have any bumps in last 2.5 sec that
    //set heart rate to zero
    if(lastTimePeak<currentTimeECG-4.0f)
    {
        [self resetState];
    }
    
    if(heartRate>300)
    {
        [self resetState];
    }

}


-(void) calculateECGAnalysis:(float *) newData numberOfFrames:(UInt32) numOfFrames selectedChannel:(UInt32) selectedChannel
{
    float zero = 0.0f;
    //get selected channel
    vDSP_vsadd((float *)&newData[selectedChannel],
               numberOfChannels,
               &zero,
               singleChannelBuffer,
               1,
               numOfFrames);
    //singleChannelBuffer = newData;
    
    
    
    
    float oneSampleTime = (1.0f/channelSamplingRate);
    
    //filter only interesting part of signal
    [HPF filterData:singleChannelBuffer numFrames:numOfFrames numChannels:1];
    [LPF filterData:singleChannelBuffer numFrames:numOfFrames numChannels:1];
    
    //get max of signal for normalization
    float tempMaxima = 0.0f;
    vDSP_maxv (singleChannelBuffer,
               1,
               &tempMaxima,
               numOfFrames
               );
    if(tempMaxima>maxValueForECG)
    {
        //slowly raize maximum
        maxValueForECG = 0.85 * maxValueForECG + 0.15 * tempMaxima;
    }
    //decay factor. If Maximum change over time and become lower
    maxValueForECG *=0.999;
   // NSLog(@"%f",maxValueForECG );
    
    //normalize signal only after 3 secconds from offset of signal
    //we give enough time for filters to initialize
    if(currentTimeECG>3.0f)
    {
        vDSP_vsdiv (
                    singleChannelBuffer,
                    1,
                    &maxValueForECG,
                    singleChannelBuffer,
                    1,
                    numOfFrames
                    );
    }
    
    //square signal so that we react on both signs of signal
     vDSP_vsq(
     singleChannelBuffer
     ,1
     ,singleChannelBuffer
     ,1
     ,numOfFrames);
    
     //get only low pass signal. Substitute for moving average/ window sum function
    //it eliminates multipe peaks
     [LPF2 filterData:singleChannelBuffer numFrames:numOfFrames numChannels:1];
    

    //find peaks
    for(int i=0;i<numOfFrames;i++)
    {
        if(lastSampleECG<threshold && singleChannelBuffer[i]>threshold && currentTimeECG>3.0f)
        {
            //we jumped over threshold
            numberOfPeaksDetected++;
            if(numberOfPeaksDetected>3)
            {
                heartBeatPresent = YES;
                
               [[NSNotificationCenter defaultCenter] postNotificationName:HEART_BEAT_NOTIFICATION object:self];
                
                numberOfPeaksDetected = 4;
                //calculate average for last 3 peaks
                heartRate = ((secondLastTimePeak-thirdLastTimePeak)+(lastTimePeak-secondLastTimePeak)+((currentTimeECG+i*oneSampleTime)-lastTimePeak))/3.0f;
                heartRate = 60.0f/heartRate;
                //NSLog(@"%f",heartRate);
            }
            //refresh peaks
            thirdLastTimePeak = secondLastTimePeak;
            secondLastTimePeak = lastTimePeak;
            lastTimePeak = currentTimeECG+i*oneSampleTime;
            
        }
        lastSampleECG = singleChannelBuffer[i];
    }
    //calculate base time for next frame of data
    currentTimeECG+=numOfFrames*oneSampleTime;
    
    //if we didn't have any bumps in last 2.5 sec that
    //set heart rate to zero
    if(lastTimePeak<currentTimeECG-4.0f)
    {
        [self resetState];
    }
    
    if(heartRate>300)
    {
        [self resetState];
    }
}

-(void) resetState
{
    heartRate = 0.0;
    numberOfPeaksDetected = 0;
    heartBeatPresent = NO;
    thirdLastTimePeak = 0.0;
    secondLastTimePeak = 0.0f;
    lastTimePeak = 0.0f;
    currentTimeECG = 0.0f;

}


@end
