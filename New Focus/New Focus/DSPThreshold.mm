/*
 *  DSPThreshold.cpp
 *  oScope
 *
 *  Created by Alex Wiltschko on 5/8/10.
 *  Copyright 2010 Alex Wiltschko. All rights reserved.
 *
 */

#include "DSPThreshold.h"

DSPThreshold :: ~DSPThreshold()
{
    free(triggeredSegmentHistory);
}


DSPThreshold :: DSPThreshold (RingBuffer *externalRingBuffer, UInt32 numSamplesInHistory, UInt32 numTriggersInHistory)
{
    
    mThresholdValue = 0.0f;
	mExternalRingBuffer = externalRingBuffer;
	mNumSamplesInTriggerBuffer = numSamplesInHistory;
    mNumTriggersInHistory = numTriggersInHistory;
	
    mThresholdDirection = BBThresholdTypeCrossingUp;
    mLastFreshSample = 0;
    isTriggered = NO;
    haveAllAudio = NO;
    
    triggeredSegmentHistory = (TriggeredSegmentHistory *)calloc(1, sizeof(TriggeredSegmentHistory));
    triggeredSegmentHistory->sizeOfMovingAverage = (mNumTriggersInHistory <= kNumSegmentsInTriggerAverage) ? mNumTriggersInHistory : kNumSegmentsInTriggerAverage;
    triggeredSegmentHistory->movingAverageIncrement = 1;
    triggeredSegmentHistory->currentSegment = 0; // let's just be explicit.

}


int DSPThreshold:: FindThresholdCrossing(const float *data, UInt32 inNumberFrames, UInt32 stride)
{
	// If we're looking for an upward threshold crossing
	if (mThresholdDirection == BBThresholdTypeCrossingUp) {
		for (int i=1; i < inNumberFrames; ++i) {
			// if a sample is above the threshold
			if (data[i] > mThresholdValue) {
				// and the last sample isn't...
				if (data[i-1] < mThresholdValue){
					// then we've found an upwards threshold crossing.
					return i;
				}
			}
		}
	}
	// If we're looking for a downwards threshold crossing
	else if (mThresholdDirection == BBThresholdTypeCrossingDown) {
		for (int i=1; i < inNumberFrames; ++i) {
			// if a sample is below the threshold...
			if (data[i] < mThresholdValue) {
				// and the previous sample is...
				if (data[i-1] > mThresholdValue){
					// then we've found a downward threshold crossing.
					return i;
				}
			}
		}
	}
	// If we haven't returned anything by now, we haven't found anything.
	// So, we return -1.
	return -1;
	
}

void DSPThreshold :: ProcessNewAudio(const float *incomingAudio, int numFrames, int numChannels)
{
	
	static int middlePoint = kNumPointsInTriggerBuffer/2;
    
	TriggeredSegmentHistory *th = triggeredSegmentHistory;
	
    //	NSLog(@"Num segments in average %d, current segments %d, num total available segments %d", th->sizeOfMovingAverage, th->currentSegment, kNumSegmentsInTriggerAverage);
	
    
	// ******************************************************
	// ** Check for a threshold crossing in the new audio
	// ******************************************************
	if ( !isTriggered ) {
		
		int indexThresholdCrossing = FindThresholdCrossing(incomingAudio, numFrames, numChannels);
		
		if (indexThresholdCrossing != -1) {
            
			isTriggered = YES;
			haveAllAudio = NO;
						
			// Increment the current trigger segment ...
			th->currentSegment = (th->currentSegment+1) % kNumSegmentsInTriggerAverage;
            
			// ... and fill it up with the triggered audio
            UInt32 numSamplesToRequest = middlePoint - indexThresholdCrossing + numFrames;
            mLastFreshSample = middlePoint - indexThresholdCrossing;
            mExternalRingBuffer->FetchFreshData2(&th->triggeredSegments[th->currentSegment][0], numSamplesToRequest, 0, 1);
            
            // The ringbuffer call above captures what used to happen below:
            /*
			UInt32 firstSampleRequested = secondStageBuffer->lastWrittenIndex - lastFreshSample - inNumberFrames;
			UInt32 buffLen = secondStageBuffer->sizeOfBuffer - 1;

			for (int i=0; i < lastFreshSample; ++i) {
				th->triggeredSegments[th->currentSegment][i] = secondStageBuffer->data[(i + firstSampleRequested) & buffLen];
			}
			*/
            
			th->lastReadSample[th->currentSegment] = mLastFreshSample;
			th->lastWrittenSample[th->currentSegment] = 0;
            
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
			
			idx = (th->currentSegment+i) % kNumSegmentsInTriggerAverage;
			needMoreAudio = th->lastReadSample[idx] < (kNumPointsInTriggerBuffer-1); // check if it's a full buffer
			
			if (needMoreAudio) {
				numSamplesLeft = kNumPointsInTriggerBuffer - th->lastReadSample[idx];
				numSamplesNeeded = (numSamplesLeft < numFrames) ? numSamplesLeft : numFrames;
				
				memcpy(&th->triggeredSegments[idx][th->lastReadSample[idx]], incomingAudio, numSamplesNeeded*sizeof(float));
				
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
    triggeredSegmentHistory->movingAverageIncrement = 0;
    triggeredSegmentHistory->currentSegment = 0; // let's just be explicit.
    memset(triggeredSegmentHistory->averageSegment, 0, kNumPointsInTriggerBuffer*sizeof(float));
    for (int i=0; i < kNumSegmentsInTriggerAverage; ++i) {
        memset(triggeredSegmentHistory->triggeredSegments[i], 0, kNumPointsInTriggerBuffer*sizeof(float));
        triggeredSegmentHistory->lastReadSample[i] = 0;
        triggeredSegmentHistory->lastWrittenSample[i] = 0;
    }

}

void DSPThreshold :: SetNumTriggersInHistory(UInt32 numTriggersInHistory)
{
    
    mNumTriggersInHistory = numTriggersInHistory;
    triggeredSegmentHistory->sizeOfMovingAverage = (mNumTriggersInHistory < kNumSegmentsInTriggerAverage) ? mNumTriggersInHistory : kNumSegmentsInTriggerAverage;
    ClearHistory();
    
}

void DSPThreshold :: SetThreshold(float newThreshold)
{
    mThresholdValue = newThreshold;
    ClearHistory();
}

//Returns average of all triggered signal intervals. Intervals are centered so that trigger point is in the middle
//numFrames/2 left from the center to numFrames/2 right from the center
void DSPThreshold :: GetCenteredTriggeredData(float *outData, UInt32 numFrames, UInt32 stride)
{
    
    
    
	TriggeredSegmentHistory *th = triggeredSegmentHistory;
	
	UInt32 newestIdx = (th->currentSegment);
	UInt32 oldestIdx = (th->currentSegment - th->movingAverageIncrement + 1) % kNumSegmentsInTriggerAverage;
    
	UInt32 idx;
	UInt32 lastWrit;
	UInt32 lastRead;
        
    // If we've only got one segment in the history,
    // then we'll just overwrite the averageSegment buffer with the current data.
    if (triggeredSegmentHistory->sizeOfMovingAverage == 1) {
        
        UInt32 offset = (kNumPointsInTriggerBuffer - numFrames)/2;
        float zero = 0.0f;
        vDSP_vsadd(&th->triggeredSegments[newestIdx][offset], 1, &zero, outData, stride, numFrames);        
        if (mLastFreshSample > (kNumPointsInTriggerBuffer + numFrames)/2)
            isTriggered = NO;

    }
    
    
    // Otherwise, do all that fancy trigger averaging.
    else {
        
        // Take out the oldest stuff if we've filled up our buffer
        if (th->movingAverageIncrement == th->sizeOfMovingAverage) {
            for (int i=0; i < th->lastWrittenSample[oldestIdx]; ++i) {
                th->averageSegment[i] -= th->triggeredSegments[oldestIdx][i];
            }
            th->lastWrittenSample[oldestIdx] = 0;
            th->lastReadSample[oldestIdx] = 0;
        }
        
        // Add in the newest stuff
        for (int i=0; i < th->movingAverageIncrement; ++i) {
            idx = (newestIdx - i) % kNumSegmentsInTriggerAverage;
            lastWrit = th->lastWrittenSample[idx];
            lastRead = th->lastReadSample[idx];
            if (lastWrit < lastRead) {
                for (int j = lastWrit; j < lastRead; ++j) {
                    th->averageSegment[j] += (float)th->triggeredSegments[idx][j];
                }
                th->lastWrittenSample[idx] = lastRead;
            }
        }
        
        UInt32 offset = (kNumPointsInTriggerBuffer - numFrames)/2;
        float normfactor = 1.0 / (float)th->movingAverageIncrement;
        vDSP_vsmul(&th->averageSegment[offset], 1, &normfactor, outData, stride, numFrames);
        
        if (mLastFreshSample > (kNumPointsInTriggerBuffer + numFrames)/2)
            isTriggered = NO;
        

    }
}

