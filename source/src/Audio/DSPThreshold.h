/*
 *  DSPThreshold.h
 *  oScope
 *	
 *  Created by Alex Wiltschko on 5/8/10.
 *
 */

#import <Foundation/Foundation.h>
#include "RingBuffer.h"

#define kNumPointsInVertexBuffer 105840//65536
#define kNumPointsInTriggerBuffer kNumPointsInVertexBuffer
#define kNumSegmentsInTriggerAverage 100

// TODO: how are we going to trigger on one channel and grab data from the others?
// TODO: how do we tell how big we're going to make our trigger buffer?


typedef enum BBThresholdType
{
	BBThresholdTypeCrossingUp = 0,
	BBThresholdTypeCrossingDown,
    BBThresholdTypeNone
    
} BBThresholdType;

typedef struct _triggeredSegmentHistory {
	float triggeredSegments[kNumSegmentsInTriggerAverage][kNumPointsInVertexBuffer];
    float averageSegment[kNumPointsInVertexBuffer];//average vector
	UInt32 lastReadSample[kNumSegmentsInTriggerAverage];//index of end of fresh data in segment
	UInt32 lastWrittenSample[kNumSegmentsInTriggerAverage];//index of end of data added to average vector
	UInt32 currentSegment;
	UInt32 sizeOfMovingAverage; //Although there are kNumSegmentsInTriggerAverage,
    // we may choose to use a moving average less than that.
    UInt32 movingAverageIncrement; //This will start at 1 and increment
    // until sizeOfMovingAverage is reached
} TriggeredSegmentHistory;


class DSPThreshold {

	public:
        DSPThreshold(RingBuffer *externalRingBuffer, UInt32 numSamplesInHistory, UInt32 numTriggersInHistory, UInt32 numberOfChannels);
        ~DSPThreshold();
        void ProcessNewAudio(float *incomingAudio, UInt32 numFrames);
        void SetNumberOfChannels(UInt32 newNumOfChannels);
    
        // Puts the trigger point in the center of outData (it's best to display things that way
        void GetCenteredTriggeredData(float *outData, UInt32 numFrames, UInt32 stride, UInt32 whichChannel);

		BBThresholdType GetThresholdDirection() { return mThresholdDirection; }
        float GetThreshold() { return mThresholdValue; }
        UInt32 GetLastFreshSample() { return mLastFreshSample; }
        BOOL GetIsTriggered() { return isTriggered; }
        UInt32 GetNumTriggersInHistory() { return mNumTriggersInHistory; }
    
        void SetThreshold(float newThreshold);
        void SetRingBuffer(RingBuffer *newRingBuffer);
		void SetThresholdDirection(BBThresholdType newDirection) { mThresholdDirection = newDirection; }
        void SetNumTriggersInHistory(UInt32 numTriggersInHistory);
        void SetSelectedChannel(int newSelectedChannel);
	
	private:
	
		RingBuffer *mExternalRingBuffer; // we'll let somebody else keep track of the streaming history
        float mThresholdValue;
        UInt32 mLastFreshSample;//last fresh samples in buffers (triggeredSegments[][mLastFreshSample])
        UInt32 mNumFramesLastUsedForDisplay;
        UInt32 mNumTriggersInHistory;
    
        bool isTriggered;
        bool haveAllAudio;
        int _numberOfChannels;
        int _selectedChannel;
		UInt32 mNumSamplesInTriggerBuffer;
		BBThresholdType mThresholdDirection;
        TriggeredSegmentHistory     *triggeredSegmentHistory;

        int FindThresholdCrossing(const float *data, UInt32 inNumberFrames,UInt32 selectedChannel, UInt32 stride);
    
        void ClearHistory();
        // Deprecated threshold-crossing-finding
        // ==============================
//		float mScratchSpace[8192]; // the 8192 is an over-allocation of a fresh segment of audio.
//		vDSP_Length mCrossingIndices[8192];
//		int CheckForCrossing(const float *data, int numFrames, int stride);

				
};


/* Default switch values
 
 lookingForThreshold = true
 outputBufferIsFull = true

*/




/* ThresholdDetection (activated on NewDataAvailable signal)

 thresholdDetectionLive?
 
 lookingForThreshold?
 
 threhsoldCrossingIndex = checkForThresholdCrossing
 
 thresholdCrossingIndex not nil?
 
 send out NewThresholdCrossingAvailable signal with crossing index

*/


/* StartAcquiringTriggeredSegment (activated on ThresholdCrossingStatus signal)
 
 lookingForThreshold = false
 outputBufferIsFull = false
 
*/



/* TriggeredSegmentRetrieval (activated on NewDataAvailable signal)
 
 outputBufferIsFull = checkIfOutputBufferIsFull()
 
 outputBufferIsFull is false?
 
 addNewDataToTriggeredData	
 
 outputBufferIsFull is true?
 
 
 
*/

