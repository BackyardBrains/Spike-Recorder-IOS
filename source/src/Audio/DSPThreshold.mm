/*
 *  DSPThreshold.cpp
 *  oScope
 *
 *  Created by Alex Wiltschko on 5/8/10.
 *  Copyright 2010 Alex Wiltschko. All rights reserved.
 *
 */

#include "DSPThreshold.h"
#include <iostream>

DSPThreshold :: ~DSPThreshold()
{
    free(triggeredSegmentHistory);
}


DSPThreshold :: DSPThreshold (RingBuffer *externalRingBuffer, UInt32 numSamplesInHistory, UInt32 numTriggersInHistory, UInt32 numberOfChannels)
{
    
    mThresholdValue = 0.0f;
	mExternalRingBuffer = externalRingBuffer;
	mNumSamplesInTriggerBuffer = numSamplesInHistory;
    mNumTriggersInHistory = numTriggersInHistory;
	
    mThresholdDirection = BBThresholdTypeCrossingUp;
    mLastFreshSample = 0;//index of last fresh sample that we got
    isTriggered = NO;
    haveAllAudio = NO;
    _numberOfChannels = numberOfChannels;
    _selectedChannel = 0;
    triggeredSegmentHistory = (TriggeredSegmentHistory *)calloc(numberOfChannels, sizeof(TriggeredSegmentHistory));
    for(int i=0;i<numberOfChannels;i++)
    {
        triggeredSegmentHistory[i].sizeOfMovingAverage = (mNumTriggersInHistory <= kNumSegmentsInTriggerAverage) ? mNumTriggersInHistory : kNumSegmentsInTriggerAverage;
        triggeredSegmentHistory[i].movingAverageIncrement = 1;
        triggeredSegmentHistory[i].currentSegment = 0; // let's just be explicit.
    }

}

void DSPThreshold:: SetRingBuffer(RingBuffer *newRingBuffer)
{
    mExternalRingBuffer = newRingBuffer;
}

void DSPThreshold:: SetNumberOfChannels(UInt32 newNumOfChannels)
{
    if(triggeredSegmentHistory)
    {
        free(triggeredSegmentHistory);
    }
    _numberOfChannels = newNumOfChannels;
    _selectedChannel = 0;
    triggeredSegmentHistory = (TriggeredSegmentHistory *)calloc(newNumOfChannels, sizeof(TriggeredSegmentHistory));
    for(int i=0;i<newNumOfChannels;i++)
    {
        triggeredSegmentHistory[i].sizeOfMovingAverage = (mNumTriggersInHistory <= kNumSegmentsInTriggerAverage) ? mNumTriggersInHistory : kNumSegmentsInTriggerAverage;
        triggeredSegmentHistory[i].movingAverageIncrement = 1;
        triggeredSegmentHistory[i].currentSegment = 0; // let's just be explicit.
    }
    ClearHistory();
}


int DSPThreshold:: FindThresholdCrossing(const float *data, UInt32 inNumberFrames,UInt32 selectedChannel, UInt32 stride)
{
    
    crossingIndex =-1;
	// If we're looking for an upward threshold crossing
	if (mThresholdDirection == BBThresholdTypeCrossingUp) {
		for (int i=selectedChannel+stride; i < inNumberFrames;i+=stride) {
			// if a sample is above the threshold
			if (data[i] > mThresholdValue) {
				// and the last sample isn't...
				if (data[i-1] <= mThresholdValue){
					// then we've found an upwards threshold crossing.
                    crossingIndex = i/stride;
					return crossingIndex;
				}
			}
		}
	}
	// If we're looking for a downwards threshold crossing
	else if (mThresholdDirection == BBThresholdTypeCrossingDown) {
		for (int i=selectedChannel+stride; i < inNumberFrames; i+=stride) {
			// if a sample is below the threshold...
			if (data[i] < mThresholdValue) {
				// and the previous sample is...
				if (data[i-stride] >= mThresholdValue){
					// then we've found a downward threshold crossing.
                    crossingIndex = i/stride;
					return crossingIndex;
				}
			}
		}
	}
	// If we haven't returned anything by now, we haven't found anything.
	// So, we return -1.
    
	return crossingIndex;
	
}


int DSPThreshold::GetCrossingIndex(void)
{
    return crossingIndex;
}


void DSPThreshold :: ProcessNewAudio(float *incomingAudio, UInt32 numFrames)
{
	
	static int middlePoint = kNumPointsInTriggerBuffer/2;
    
	TriggeredSegmentHistory *th = &triggeredSegmentHistory[_selectedChannel];
	
    //	NSLog(@"Num segments in average %d, current segments %d, num total available segments %d", th->sizeOfMovingAverage, th->currentSegment, kNumSegmentsInTriggerAverage);
	
    
	// ******************************************************
	// ** Check for a threshold crossing in the new audio
	// ******************************************************
	if ( !isTriggered ) {
		
		int indexThresholdCrossing = FindThresholdCrossing(incomingAudio, numFrames, _selectedChannel, _numberOfChannels);
		
		if (indexThresholdCrossing != -1) {
            
			isTriggered = YES;//don't do new triggers
			haveAllAudio = NO;//we need to fill buffers until the end
						
			// Increment the current trigger segment ...
			th->currentSegment = (th->currentSegment+1) % kNumSegmentsInTriggerAverage;
            
			// ... and fill it up with the triggered audio and make sure that triggered sample is
            //at he center of buffer
            //Since new data is not yet in main circular buffer ask just for  (middlePoint - indexThresholdCrossing) point.
            //That will center threshold point in the middle after we add new data
           
            UInt32 numSamplesToRequest = middlePoint - indexThresholdCrossing;// + numFrames;

            for(int chi=0;chi<_numberOfChannels;chi++)
            {
                //at this point new data is already added to ring buffer
                mExternalRingBuffer->FetchFreshData2(&triggeredSegmentHistory[chi].triggeredSegments[th->currentSegment][0], numSamplesToRequest, chi, 1);
            }
            //put last fresh sample index as if we didn't add any data from current incomingAudio
            //so that we can add it in uniform way with other buffers
            mLastFreshSample = middlePoint - indexThresholdCrossing;
            
            // The ringbuffer call above captures what used to happen below:
            /*
			UInt32 firstSampleRequested = secondStageBuffer->lastWrittenIndex - lastFreshSample - inNumberFrames;
			UInt32 buffLen = secondStageBuffer->sizeOfBuffer - 1;

			for (int i=0; i < lastFreshSample; ++i) {
				th->triggeredSegments[th->currentSegment][i] = secondStageBuffer->data[(i + firstSampleRequested) & buffLen];
			}
			*/
            
			th->lastReadSample[th->currentSegment] = mLastFreshSample;//end of valid data. Rest we need to fill with new data
			th->lastWrittenSample[th->currentSegment] = 0;//last written to average buffer
            
            //increment the moving average until it reaches the desired number
            if (th->movingAverageIncrement < th->sizeOfMovingAverage)
                ++th->movingAverageIncrement;
		}
		
	}
    
	// ******************************************************
	// ** Fill in the audio for the triggered segments
	// ******************************************************
	if (!haveAllAudio) {
		BOOL needMoreAudio;
		UInt32 i, numSamplesLeft, numSamplesNeeded, idx;
		for (i=0; i<kNumSegmentsInTriggerAverage; ++i) { // for every saved triggered segment
			
            //index of segment that we will chack if needs more data from new incomingAudio
			idx = (th->currentSegment+i) % kNumSegmentsInTriggerAverage;
			needMoreAudio = th->lastReadSample[idx] < (kNumPointsInTriggerBuffer-1); // check if it's a full buffer
			
			if (needMoreAudio) {
				numSamplesLeft = kNumPointsInTriggerBuffer - th->lastReadSample[idx];//how much data we need to fill to the end
                //if we have less than we need take just what we have
				numSamplesNeeded = (numSamplesLeft < numFrames) ? numSamplesLeft : numFrames;
				
                //append new data after th->lastReadSample[idx]
                for(int chIndex=0;chIndex<_numberOfChannels;chIndex++)
                {
                    float zero = 0.0f;
                    vDSP_vsadd(&incomingAudio[chIndex],
                               _numberOfChannels,
                               &zero,
                               &triggeredSegmentHistory[chIndex].triggeredSegments[idx][th->lastReadSample[idx]],
                               1,
                               numSamplesNeeded);
                }
				
                //update end of valid data. Rest we need to fill with new data in next call
				th->lastReadSample[idx] += numSamplesNeeded;

                if (i == 0) {
                    mLastFreshSample += numSamplesNeeded;
                }
                    
				
			}
		}
		
		// Check specifically the current segment if it's full of audio. If it's full, then we can release the trigger.
		if (mLastFreshSample >= (kNumPointsInTriggerBuffer-1)) {
			haveAllAudio = YES;
			isTriggered = NO; // this should be reset within [triggerView drawView] well beforehand.
		}
		
	}
	
}

void DSPThreshold :: ClearHistory()
{
    
    isTriggered = NO;
    haveAllAudio = NO;
    
    // Clear out the trigger segment history
    for(int chIndex=0;chIndex<_numberOfChannels;chIndex++)
    {
        triggeredSegmentHistory[chIndex].movingAverageIncrement = 0;
        triggeredSegmentHistory[chIndex].currentSegment = 0; // let's just be explicit.
        memset(triggeredSegmentHistory[chIndex].averageSegment, 0, kNumPointsInTriggerBuffer*sizeof(float));
        for (int i=0; i < kNumSegmentsInTriggerAverage; ++i) {
            memset(triggeredSegmentHistory[chIndex].triggeredSegments[i], 0, kNumPointsInTriggerBuffer*sizeof(float));
            triggeredSegmentHistory[chIndex].lastReadSample[i] = 0;
            triggeredSegmentHistory[chIndex].lastWrittenSample[i] = 0;
        }
    }

}

void DSPThreshold :: SetNumTriggersInHistory(UInt32 numTriggersInHistory)
{
    
    mNumTriggersInHistory = numTriggersInHistory;
    for(int chIndex=0;chIndex<_numberOfChannels;chIndex++)
    {
        triggeredSegmentHistory[chIndex].sizeOfMovingAverage = (mNumTriggersInHistory < kNumSegmentsInTriggerAverage) ? mNumTriggersInHistory : kNumSegmentsInTriggerAverage;
    }
    ClearHistory();
    
}

void DSPThreshold :: SetThreshold(float newThreshold)
{
    mThresholdValue = newThreshold;
    ClearHistory();
}

void DSPThreshold :: SetSelectedChannel(int newSelectedChannel)
{
    NSLog(@"Selected channel in THRESHOLD %d", newSelectedChannel);
    _selectedChannel = newSelectedChannel;
    ClearHistory();
}


//NOTE: SHould return only one channel
//Returns average of all triggered signal intervals. Intervals are centered so that trigger point is in the middle
//numFrames/2 left from the center to numFrames/2 right from the center
void DSPThreshold :: GetCenteredTriggeredData(float *outData, UInt32 numFrames, UInt32 whichChannel, UInt32 stride)
{
    
    if(numFrames>kNumPointsInTriggerBuffer)
    {
        numFrames =kNumPointsInTriggerBuffer;
        NSLog(@"\n\n Wrong length of data in GetCenteredTriggeredData\n\n");
        
    }
    
	TriggeredSegmentHistory *th = &triggeredSegmentHistory[_selectedChannel];
	
    //last segment that we are averraging
	UInt32 newestIdx = (th->currentSegment);
    //index of oldest segment that we are averraging
	UInt32 oldestIdx = (th->currentSegment - th->movingAverageIncrement + 1) % kNumSegmentsInTriggerAverage;
    
	UInt32 idx;
	UInt32 lastWrit;
	UInt32 lastRead;
        
    // If we've only got one segment in the history,
    // then we'll just overwrite the averageSegment buffer with the current data.
    if (triggeredSegmentHistory->sizeOfMovingAverage == 1) {
        
        UInt32 offset = (kNumPointsInTriggerBuffer - numFrames)/2;
        float zero = 0.0f;
        vDSP_vsadd(&triggeredSegmentHistory[whichChannel].triggeredSegments[newestIdx][offset], 1, &zero, outData, stride, numFrames);
        
        //if we have enought data to display full signal on screen
        //[kNumPointsInTriggerBuffer-numFrames/2,kNumPointsInTriggerBuffer+numFrames/2]
        //than start new triggering
        if (mLastFreshSample > (kNumPointsInTriggerBuffer + numFrames)/2)
            isTriggered = NO;

    }
    
    
    // Otherwise, do all that fancy trigger averaging.
    else {
        
        // Take out the oldest stuff if we've filled up our buffer
        if (th->movingAverageIncrement == th->sizeOfMovingAverage) {
            for(int chIndex=0;chIndex<_numberOfChannels;chIndex++)
            {
                for (int i=0; i < th->lastWrittenSample[oldestIdx]; ++i) {
                    triggeredSegmentHistory[chIndex].averageSegment[i] -= triggeredSegmentHistory[chIndex].triggeredSegments[oldestIdx][i];
                }
            }
            th->lastWrittenSample[oldestIdx] = 0;
            th->lastReadSample[oldestIdx] = 0;
        }
        
        // Add in the newest stuff
        for (int i=0; i < th->movingAverageIncrement; ++i) {//go through all segments
            idx = (newestIdx - i) % kNumSegmentsInTriggerAverage;
            lastWrit = th->lastWrittenSample[idx];//get end index already added data
            lastRead = th->lastReadSample[idx];//get end index of new data
            if (lastWrit < lastRead) {//id we didn't add new data add it
                for(int chIndex=0;chIndex<_numberOfChannels;chIndex++)
                {
                    for (int j = lastWrit; j < lastRead; ++j) {//add new data
                        triggeredSegmentHistory[chIndex].averageSegment[j] += (float)triggeredSegmentHistory[chIndex].triggeredSegments[idx][j];
                    }
                }
                th->lastWrittenSample[idx] = lastRead;//we added all that was new so lastReadSample == lastWrittenSample
            }
        }
        
        
        UInt32 offset = (kNumPointsInTriggerBuffer - numFrames)/2;
        float normfactor = 1.0 / (float)th->movingAverageIncrement;
        vDSP_vsmul(&(triggeredSegmentHistory[whichChannel].averageSegment[offset]), 1, &normfactor, outData, stride, numFrames);
        
        if (mLastFreshSample > (kNumPointsInTriggerBuffer + numFrames)/2)
            isTriggered = NO;
        

    }
}

