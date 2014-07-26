//
//  DSPAnalysis.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/1/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "RingBuffer.h"
#include <OpenGLES/ES2/gl.h>

typedef struct {
    float Position[3];
    float Color[4];
} Vertex;

class DSPAnalysis {
    
public:
    DSPAnalysis();
    ~DSPAnalysis();
    //Calculate Root mean square of data array
    float RMSSelection(const float *data, int64_t mSizeOfBuffer);
    //Calculate standard deviation of data array
    float SDT(const float *data, int64_t mSizeOfBuffer);
    
    //Simple FFT
    
    //Init FFT. Length of window must be 2^N. Frequency resolution samplingRate/LengthOfWindow
    void InitFFT(RingBuffer *externalRingBuffer, UInt32 numberOfChannels, UInt32 samplingRate, UInt32 lengthOfWindow);
    //Calculate FFT for one channel and put result in FFTMagnitude array. We take input signal from mExternalRingBuffer
    float * CalculateFFT(UInt32 whichChannel);
    //Result magnitude of FFT calculation
    float * FFTMagnitude;
    
    //Dynamic FFT
     void InitDynamicFFT(RingBuffer *externalRingBuffer, UInt32 numberOfChannels, UInt32 samplingRate, UInt32 lengthOfWindow, UInt32 percOverlapOfWindows, float bufferMaxSeconds);
    //Calculate FFT for new data (It can calculate one or more window depending on amount of data that arrived)
    void CalculateDynamicFFT(const float *data, UInt32 numberOfFramesInData, UInt32 whichChannel);
    float ** FFTDynamicMagnitude;
    

    //length of FFT window. Must be 2^N
    UInt32 LengthOfFFTData;
    UInt32 GraphBufferIndex;
    UInt32 NumberOfGraphsInBuffer;
private:
    
    UInt32 mPercOverlapOfWindow;
    UInt32 mNumberOfSamplesBetweenWindows;
    UInt32 mNumberOfGraphsInBuffer;
    float mBufferMaxSec;
    UInt32 mNumberOfSamplesWhaitingForAnalysis;
    
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
    float maxMagnitude;
    float halfMaxMagnitude;
};
