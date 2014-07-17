//
//  DSPAnalysis.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/1/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "RingBuffer.h"
class DSPAnalysis {
    
public:
    DSPAnalysis();
    ~DSPAnalysis();
    float RMSSelection(const float *data, int64_t mSizeOfBuffer);
    float SDT(const float *data, int64_t mSizeOfBuffer);
    void InitFFT(RingBuffer *externalRingBuffer, UInt32 numberOfChannels, UInt32 samplingRate, UInt32 lengthOfWindow);
    float * CalculateFFT(UInt32 whichChannel);
    float * FFTMagnitude;
    UInt32 LengthOfFFTData; //length of FFT window. Must be 2^N
private:
	
    RingBuffer *mExternalRingBuffer; // we'll let somebody else keep track of the streaming history
    UInt32 mNumberOfChannels;
    float mSamplingRate;
    float *mInputBuffer;
    float *mOutputBuffer;
    UInt32 mLengthOfWindow;
    COMPLEX_SPLIT A;
    FFTSetup fftSetup;
};
