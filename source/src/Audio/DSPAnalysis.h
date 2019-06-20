//
//  DSPAnalysis.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/1/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "RingBuffer.h"
#import "BBAudioFileReader.h"


class DSPAnalysis {
    
public:
    DSPAnalysis();
    ~DSPAnalysis();
    
    
    
    //Calculate Root mean square of data array
    float RMSSelection(const float *data, int64_t mSizeOfBuffer);
    //Calculate standard deviation of data array
    float SDT(const float *data, int64_t mSizeOfBuffer);
    //calculate basic stats of signal min, max, mean, STD
    void calculateBasicStats(const float *data, int64_t mSizeOfBuffer, float * inStd, float * inMin, float * inMax, float * inMean);
    
    
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
    void CalculateDynamicFFTDuringSeek(BBAudioFileReader *fileReader, UInt32 numberOfFramesToGet, UInt32 startFrame, UInt32 numberOfChannels, UInt32 whichChannel);
    float ** FFTDynamicMagnitude;
    void resetFFTMagnitudeBuffer();
    
    
    //length of FFT window. Must be 2^N
    UInt32 dLengthOfFFTData;
    UInt32 LengthOf30HzData;
    UInt32 GraphBufferIndex;
    UInt32 NumberOfGraphsInBuffer;
    float oneFrequencyStep;
private:
    
    UInt32 mPercOverlapOfWindow;
    UInt32 oNumberOfSamplesBetweenWindows;
    UInt32 mNumberOfGraphsInBuffer;
    float mBufferMaxSec;
    UInt32 oNumberOfSamplesWhaitingForAnalysis;
    
    // Ring buffer used as an input for FFT
    RingBuffer *mExternalRingBuffer;
    //Number of channels at input of FFT
    UInt32 mNumberOfChannels;
    //Sampling rate of input data in mExternalRingBuffer
    float oSamplingRate;
    //FFT calculation variables
    float *oInputBuffer;
    float *mOutputBuffer;
    UInt32 oLengthOfWindow;
    float downsamplingFactor;
    COMPLEX_SPLIT A;
    FFTSetup fftSetup;
    //FFTSetup fftSetupOptimized;
    float maxMagnitude;
    float halfMaxMagnitude;
    //float maxMagnitudeOptimized;
    //float halfMaxMagnitudeOptimized;
    
    
    
};
