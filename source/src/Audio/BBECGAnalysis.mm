//
//  BBECGAnalysis.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 9/14/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "BBECGAnalysis.h"

@implementation BBECGAnalysis
@synthesize heartRate;



-(void) initECGAnalysisWithSamplingRate:(float) samplingRate numOfChannels:(UInt32) numOfChannels
{
    
    numberOfChannels = numOfChannels;
    channelSamplingRate = samplingRate;
    updateECGWithNumberOfFrames = 0;
    currentBeatIndex = 0;
    beatsCollected = 0;
    lastTime = 0;
     beatTimestamps = (float *)calloc(NUMBER_OF_BEATS_TO_REMEMBER, sizeof(float));
    
}

-(void) updateECGData:(float * ) data withNumberOfFrames:(UInt32) numberOfFrames numberOfChannels:(int)numOfChannels andThreshold:(float) threshold
{
    
    int crossingIndex =-1;
    int selectedChannel = 0;
    int k;
    // If we're looking for an upward threshold crossing
    if (threshold >0) {
        for (k=selectedChannel+numOfChannels; k < numberOfFrames;k+=numOfChannels) {
            // if a sample is above the threshold
            if (data[k] > threshold) {
                // and the last sample isn't...
                if (data[k-1] <= threshold){
                    // then we've found an upwards threshold crossing.
                    crossingIndex = k/numOfChannels;
                    break;
                }
            }
        }
    }
    // If we're looking for a downwards threshold crossing
    else if (threshold < 0) {
        for (int i=selectedChannel+numOfChannels; i < numberOfFrames; i+=numOfChannels) {
            // if a sample is below the threshold...
            if (data[i] < threshold) {
                // and the previous sample is...
                if (data[i-numOfChannels] >= threshold){
                    // then we've found a downward threshold crossing.
                    crossingIndex = i/numOfChannels;
                    break;
                }
            }
        }
    }
    // If we haven't returned anything by now, we haven't found anything.
    // So, we return -1.
    

    if(crossingIndex!=-1)
    {
        updateECGWithNumberOfFrames+= crossingIndex;
        [[NSNotificationCenter defaultCenter] postNotificationName:HEART_BEAT_NOTIFICATION object:self];
        beatTimestamps[currentBeatIndex] = lastTime + ((float)updateECGWithNumberOfFrames/(float)channelSamplingRate);
        
        if(beatTimestamps[currentBeatIndex]<0.2)
        {
            //interval is too small to be realistic
            updateECGWithNumberOfFrames += numberOfFrames - crossingIndex;//add full numberOfFrames
            return;
        }
        updateECGWithNumberOfFrames = numberOfFrames - crossingIndex;
        
        lastTime = beatTimestamps[currentBeatIndex];
        currentBeatIndex++;
        if(currentBeatIndex>NUMBER_OF_BEATS_TO_REMEMBER)
        {
            currentBeatIndex = 0;
        }
        beatsCollected++;
        if(beatsCollected>NUMBER_OF_BEATS_TO_REMEMBER)
        {
            beatsCollected = NUMBER_OF_BEATS_TO_REMEMBER;
        }
        
        int numberOfBeatsSummed = 0;
        float howMuchHistoryWeIncluded = 0;
        int indexOfLastSummed = currentBeatIndex-1;
        
        if(indexOfLastSummed <0)
        {
            indexOfLastSummed = NUMBER_OF_BEATS_TO_REMEMBER;
        }
        int indexOfPrevious;
        //calculate the average beat rate in last NUMBER_OF_SEC_TO_AVERAGE sec
        while((howMuchHistoryWeIncluded<NUMBER_OF_SEC_TO_AVERAGE) && (numberOfBeatsSummed<beatsCollected-1))
        {
            indexOfPrevious = indexOfLastSummed-1;
            if(indexOfPrevious<0)
            {
                indexOfPrevious = NUMBER_OF_BEATS_TO_REMEMBER;
            }
            float timeDiff = ((float)(beatTimestamps[indexOfLastSummed] - beatTimestamps[indexOfPrevious]));
            if(timeDiff>2.5)
            {
                break;
            }
            howMuchHistoryWeIncluded += timeDiff;
            indexOfLastSummed = indexOfPrevious;
            numberOfBeatsSummed++;
        }
        
        float averageTime = 1.0;
        if(numberOfBeatsSummed>0)
        {
            averageTime = howMuchHistoryWeIncluded/(float)numberOfBeatsSummed;
        
            if((60*(1.0f/averageTime))>300)
            {
                heartRate = 300;
            }
            else
            {
                heartRate = 60*(1.0f/averageTime);
                
            }
        }
        else
        {
            heartRate = 0;
        }
        
    }
    else
    {
        updateECGWithNumberOfFrames += numberOfFrames;
        
        if(updateECGWithNumberOfFrames>3*channelSamplingRate)
        {
            heartRate = 0;
            updateECGWithNumberOfFrames = 3*channelSamplingRate; //Prevent overflow
        }
    }
    
}

-(void) reset
{
    heartRate = 0.0;
    updateECGWithNumberOfFrames = 0;
    currentBeatIndex = 0;
    beatsCollected = 0;
    lastTime = 0;
}


@end
