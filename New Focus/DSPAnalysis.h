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
    //Calculate Root mean square of data array
    float RMSSelection(const float *data, int64_t mSizeOfBuffer);
    //Calculate standard deviation of data array
    float SDT(const float *data, int64_t mSizeOfBuffer);
    //Init FFT. Length of window must be 2^N. Frequency resolution samplingRate/LengthOfWindow
    void InitFFT(RingBuffer *externalRingBuffer, UInt32 numberOfChannels, UInt32 samplingRate, UInt32 lengthOfWindow);
    //Calculate FFT for one channel and put result in FFTMagnitude array. We take input signal from mExternalRingBuffer
    float * CalculateFFT(UInt32 whichChannel);
    //Result magnitude of FFT calculation
    float * FFTMagnitude;
    //length of FFT window. Must be 2^N
    UInt32 LengthOfFFTData;
private:
	// Ring buffer used as an input for FFT
    RingBuffer *mExternalRingBuffer;
    //Number of channels at input of FFT
    UInt32 mNumberOfChannels;
    //Sampling rate of input data in mExternalRingBuffer
    float mSamplingRate;
    //FFT calculation variables
    float *mInputBuffer;
    float *mOutputBuffer;
    UInt32 mLengthOfWindow;
    COMPLEX_SPLIT A;
    FFTSetup fftSetup;
};
