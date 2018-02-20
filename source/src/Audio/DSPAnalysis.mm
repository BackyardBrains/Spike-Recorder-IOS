//
//  DSPAnalysis.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/1/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "DSPAnalysis.h"
#import "RingBuffer.h"



DSPAnalysis::~DSPAnalysis()
{
    
}


DSPAnalysis::DSPAnalysis ()
{
    mInputBuffer = nil;
    mOutputBuffer = nil;
    FFTMagnitude = nil;
    FFTDynamicMagnitude = nil;
}

//------------------- Simple FFT ----------------------------------


//
//Init FFT. Length of window must be 2^N. Frequency resolution samplingRate/LengthOfWindow
//
void DSPAnalysis::InitFFT(RingBuffer *externalRingBuffer, UInt32 numberOfChannels, UInt32 samplingRate, UInt32 lengthOfWindow)
{
    mExternalRingBuffer = externalRingBuffer;
    mNumberOfChannels = numberOfChannels;
    mSamplingRate = (float)samplingRate;
    mLengthOfWindow = lengthOfWindow;//1024 - must be 2^N
    LengthOfFFTData = lengthOfWindow/2;
    
    /* vector allocations*/
    if(mInputBuffer)
    {
        free(mInputBuffer);
        free(mOutputBuffer);
        free(FFTMagnitude);
        free(A.realp);
        free(A.imagp);
    }
    mInputBuffer = new float [lengthOfWindow];
    mOutputBuffer = new float[lengthOfWindow];
    FFTMagnitude = new float[LengthOfFFTData];
    
    uint32_t log2n = log2f((float)mLengthOfWindow);
    
    A.realp = (float*) malloc(sizeof(float) * LengthOfFFTData);
    A.imagp = (float*) malloc(sizeof(float) * LengthOfFFTData);
    
    //Make FFT config
    fftSetup = vDSP_create_fftsetup(log2n, FFT_RADIX2);
}

//
//Calculate FFT for one channel and put result in FFTMagnitude array. We take input signal from mExternalRingBuffer
//it calculates FFT for last arrived signal data
//
float * DSPAnalysis::CalculateFFT(UInt32 whichChannel)
{
    //Get data from ring buffer
    mExternalRingBuffer->FetchFreshData2(mInputBuffer, mLengthOfWindow, whichChannel , 1);
    
    uint32_t log2n = log2f((float)mLengthOfWindow);
    /* Carry out a Forward FFT transform. */
    vDSP_ctoz((COMPLEX *) mInputBuffer, 2, &A, 1, LengthOfFFTData);
    vDSP_fft_zrip(fftSetup, &A, 1, log2n, FFT_FORWARD);
    
    //Calculate DC component
    FFTMagnitude[0] = sqrtf(A.realp[0]*A.realp[0]);
    
    //Calculate magnitude for all freq.
    for(int i = 1; i < LengthOfFFTData; i++){
        FFTMagnitude[i] = sqrtf(A.realp[i]*A.realp[i] + A.imagp[i] * A.imagp[i]);
    }
    
    return FFTMagnitude;
}



//----------------- Dynamic FFT -------------------------------------------

void DSPAnalysis::InitDynamicFFT(RingBuffer *externalRingBuffer, UInt32 numberOfChannels, UInt32 samplingRate, UInt32 lengthOfWindow, UInt32 percOverlapOfWindows, float bufferMaxSeconds)
{
    //First deallocate buffer before we overwrite mNumberOfGraphsInBuffer
    if(FFTDynamicMagnitude)
    {
        for(int k = 0; k < NumberOfGraphsInBuffer; k++)
        {
            delete[] FFTDynamicMagnitude[k];
        }
    }
    
    
    mExternalRingBuffer = externalRingBuffer;
    mNumberOfChannels = numberOfChannels;
    mSamplingRate = (float)samplingRate;
    mLengthOfWindow = lengthOfWindow;//1024 - must be 2^N
    LengthOfFFTData = lengthOfWindow/2;
    
    oneFrequencyStep = 0.5*samplingRate/((float)LengthOfFFTData);
    LengthOf30HzData = 32/oneFrequencyStep;//we will use only low freq. data
    
    
    if(LengthOfFFTData<2)
    {
        LengthOfFFTData = 2;
    }
    
    if(percOverlapOfWindows>99)
    {
        percOverlapOfWindows = 99;
    }
    mPercOverlapOfWindow = percOverlapOfWindows;
    
    mNumberOfSamplesBetweenWindows = mLengthOfWindow*(1.0f-(((float)percOverlapOfWindows)/100.0f));
    
    if(bufferMaxSeconds<=0.0f)
    {
        bufferMaxSeconds = 0.1;
    }
    mBufferMaxSec = bufferMaxSeconds;
    
    //we add 4 here so that we can add new data asinc with draw graph function and avoid graphic glitches
    NumberOfGraphsInBuffer =4 + (bufferMaxSeconds*mSamplingRate)/((float)mNumberOfSamplesBetweenWindows);
    
    mNumberOfSamplesWhaitingForAnalysis = 0;
    
    /* vector allocations*/
    if(mInputBuffer)
    {
        free(mInputBuffer);
        free(mOutputBuffer);
        free(FFTMagnitude);
        free(A.realp);
        free(A.imagp);
    }
    
    // It doesn't matter how big is the input buffer
    //as long as it is big enough to hold
    //one portion of data arriving from input source
    //(for mic audio it is usualy 1024)
    mInputBuffer = new float [lengthOfWindow*10];
    
    mOutputBuffer = new float[lengthOfWindow];
    
    int i,k;
    
    //Make main result buffer
    FFTDynamicMagnitude = new float*[NumberOfGraphsInBuffer];
    for(i=0;i<NumberOfGraphsInBuffer;i++)
    {
        FFTDynamicMagnitude[i] = new float[LengthOf30HzData];
    }
    
    for(i=0;i<NumberOfGraphsInBuffer;i++)
    {
        for(k=0;k<LengthOf30HzData;k++)
        {
            FFTDynamicMagnitude[i][k] = -1;
        }
    }
    
    uint32_t log2n = log2f((float)mLengthOfWindow);
    
    A.realp = (float*) malloc(sizeof(float) * LengthOfFFTData);
    A.imagp = (float*) malloc(sizeof(float) * LengthOfFFTData);
    
    //Make FFT config
    fftSetup = vDSP_create_fftsetup(log2n, FFT_RADIX2);
    GraphBufferIndex = 0;
    maxMagnitude = 20;
    halfMaxMagnitude = 20;
}


void DSPAnalysis::CalculateDynamicFFT(const float *data, UInt32 numberOfFramesInData, UInt32 whichChannel)
{
    mNumberOfSamplesWhaitingForAnalysis += numberOfFramesInData;
    int numberOfWindowsToAdd = mNumberOfSamplesWhaitingForAnalysis/mNumberOfSamplesBetweenWindows;
    
    if(numberOfWindowsToAdd==0)
    { //if we don't have enough data
        return;
    }
    
    //Get data from ring buffer
    mExternalRingBuffer->FetchFreshData2(mInputBuffer, LengthOfFFTData*2, whichChannel , 1);
    
    for(int i=0;i<numberOfWindowsToAdd;i++)
    {
        uint32_t log2n = log2f((float)mLengthOfWindow);
        /* Carry out a Forward FFT transform. */
        vDSP_ctoz((COMPLEX *) &mInputBuffer[i*mNumberOfSamplesBetweenWindows], 2, &A, 1, LengthOfFFTData);
        vDSP_fft_zrip(fftSetup, &A, 1, log2n, FFT_FORWARD);
        
        //Calculate DC component
        FFTDynamicMagnitude[GraphBufferIndex][0] = (sqrtf(A.realp[0]*A.realp[0])/halfMaxMagnitude)-1.0;
        
        //Calculate magnitude for all freq.
        for(int ind = 1; ind < LengthOf30HzData; ind++){
            FFTDynamicMagnitude[GraphBufferIndex][ind] = sqrtf(A.realp[ind]*A.realp[ind] + A.imagp[ind] * A.imagp[ind]);
            if(FFTDynamicMagnitude[GraphBufferIndex][ind]>maxMagnitude)
            {
                maxMagnitude = FFTDynamicMagnitude[GraphBufferIndex][ind];
                halfMaxMagnitude = maxMagnitude*0.5f;
            }
            // NSLog(@"%f", halfMaxMagnitude);
            FFTDynamicMagnitude[GraphBufferIndex][ind] = (FFTDynamicMagnitude[GraphBufferIndex][ind]/halfMaxMagnitude)-1.0;
        }
    }
    mNumberOfSamplesWhaitingForAnalysis -= numberOfWindowsToAdd*mNumberOfSamplesBetweenWindows;
    GraphBufferIndex = (GraphBufferIndex+1)%NumberOfGraphsInBuffer;
}



//------------------- RMS ------------------------------------------

//
// Calculate RMS of signal in data
//
float DSPAnalysis::RMSSelection(const float *data, int64_t mSizeOfBuffer)
{
    float rms;
    vDSP_rmsqv(data,1,&rms,mSizeOfBuffer);
    return rms;
}


//------------------ STD --------------------------------------------


//
// Calculate RMS of signal in data
//
float DSPAnalysis::SDT(const float *data, int64_t mSizeOfBuffer)
{
    float std;
    float mean = 0; // place holder for mean
    vDSP_meanv(data,1,&mean,mSizeOfBuffer); // find the mean of the vector
    mean = -1*mean; // Invert mean so when we add it is actually subtraction
    float *subMeanVec  = (float*)calloc(mSizeOfBuffer,sizeof(float)); // placeholder vector
    vDSP_vsadd(data,1,&mean,subMeanVec,1,mSizeOfBuffer); // subtract mean from vector
    float *squared = (float*)calloc(mSizeOfBuffer,sizeof(float)); // placeholder for squared vector
    vDSP_vsq(subMeanVec,1,squared,1,mSizeOfBuffer); // Square vector element by element
    free(subMeanVec); // free some memory
    float sum = 0; // place holder for sum
    vDSP_sve(squared,1,&sum,mSizeOfBuffer); //sum entire vector
    free(squared); // free squared vector
    std = sqrt(sum/mSizeOfBuffer); // calculated std deviation
    return std;
}

void DSPAnalysis::calculateBasicStats(const float *data, int64_t mSizeOfBuffer, float * inStd, float * inMin, float * inMax, float * inMean)
{
    float mean = 0; // place holder for mean
    vDSP_meanv(data,1,&mean,mSizeOfBuffer); // find the mean of the vector
    *inMean = mean;
    mean = -1*mean; // Invert mean so when we add it is actually subtraction
    float *subMeanVec  = (float*)calloc(mSizeOfBuffer,sizeof(float)); // placeholder vector
    vDSP_vsadd(data,1,&mean,subMeanVec,1,mSizeOfBuffer); // subtract mean from vector
    float *squared = (float*)calloc(mSizeOfBuffer,sizeof(float)); // placeholder for squared vector
    vDSP_vsq(subMeanVec,1,squared,1,mSizeOfBuffer); // Square vector element by element
    free(subMeanVec); // free some memory
    float sum = 0; // place holder for sum
    vDSP_sve(squared,1,&sum,mSizeOfBuffer); //sum entire vector
    free(squared); // free squared vector
    *inStd = sqrt(sum/mSizeOfBuffer);
    
    //find max
    vDSP_maxv(data,1,inMax,mSizeOfBuffer);
    vDSP_minv(data,1,inMin,mSizeOfBuffer);
    
}

