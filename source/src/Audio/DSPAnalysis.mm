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
    oInputBuffer = nil;
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
    oSamplingRate = (float)samplingRate;
    oLengthOfWindow = lengthOfWindow;//1024 - must be 2^N
    dLengthOfFFTData = lengthOfWindow/2;
    
    /* vector allocations*/
    if(oInputBuffer)
    {
        free(oInputBuffer);
        free(mOutputBuffer);
        free(FFTMagnitude);
        free(A.realp);
        free(A.imagp);
    }
    oInputBuffer = new float [lengthOfWindow];
    mOutputBuffer = new float[lengthOfWindow];
    FFTMagnitude = new float[dLengthOfFFTData];
    
    uint32_t log2n = log2f((float)oLengthOfWindow);
    
    A.realp = (float*) malloc(sizeof(float) * dLengthOfFFTData);
    A.imagp = (float*) malloc(sizeof(float) * dLengthOfFFTData);
    
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
    mExternalRingBuffer->FetchFreshData2(oInputBuffer, oLengthOfWindow, whichChannel , 1);
    
    uint32_t log2n = log2f((float)oLengthOfWindow);
    /* Carry out a Forward FFT transform. */
    vDSP_ctoz((COMPLEX *) oInputBuffer, 2, &A, 1, dLengthOfFFTData);
    vDSP_fft_zrip(fftSetup, &A, 1, log2n, FFT_FORWARD);
    
    //Calculate DC component
    FFTMagnitude[0] = sqrtf(A.realp[0]*A.realp[0]);
    
    //Calculate magnitude for all freq.
    for(int i = 1; i < dLengthOfFFTData; i++){
        FFTMagnitude[i] = sqrtf(A.realp[i]*A.realp[i] + A.imagp[i] * A.imagp[i]);
    }
    
    return FFTMagnitude;
}



//----------------- Dynamic FFT -------------------------------------------
#define FIXED_SIZE_OF_FFT_DATA 512
#define FIXED_SIZE_OF_WINDOW_IN_SEC 4
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
    oSamplingRate = (float)samplingRate;
    oLengthOfWindow = FIXED_SIZE_OF_WINDOW_IN_SEC*oSamplingRate;//4 seconds
    downsamplingFactor = (oLengthOfWindow/(float)FIXED_SIZE_OF_FFT_DATA);
    float dSamplingRate = oSamplingRate/downsamplingFactor;
    dLengthOfFFTData = FIXED_SIZE_OF_FFT_DATA;
    
    oneFrequencyStep = dSamplingRate/((float)dLengthOfFFTData);
    LengthOf30HzData = 32/oneFrequencyStep;//we will use only low freq. data
    
    
    if(dLengthOfFFTData<2)
    {
        dLengthOfFFTData = 2;
    }
    
    if(percOverlapOfWindows>99)
    {
        percOverlapOfWindows = 99;
    }
    mPercOverlapOfWindow = percOverlapOfWindows;
    
    oNumberOfSamplesBetweenWindows = oLengthOfWindow*(1.0f-(((float)mPercOverlapOfWindow)/100.0f));
    
    if(bufferMaxSeconds<=0.0f)
    {
        bufferMaxSeconds = 0.1;
    }
    mBufferMaxSec = bufferMaxSeconds;//6 seconds
    
    //we add 4 here so that we can add new data asinc with draw graph function and avoid graphic glitches
    NumberOfGraphsInBuffer =4 + (mBufferMaxSec*oSamplingRate)/((float)oNumberOfSamplesBetweenWindows);
    
    oNumberOfSamplesWhaitingForAnalysis = 0;
    
    /* vector allocations*/
    if(oInputBuffer)
    {
        free(oInputBuffer);
        free(mOutputBuffer);
        free(FFTMagnitude);
        free(A.realp);
        free(A.imagp);
    }
    
    // It doesn't matter how big is the input buffer
    //as long as it is big enough to hold
    //one portion of data arriving from input source
    //(for mic audio it is usualy 1024)
    oInputBuffer = new float [oLengthOfWindow*10];
    
    mOutputBuffer = new float[oLengthOfWindow];
    
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
    
    
    
    
    uint32_t log2n = log2f((float)dLengthOfFFTData);
    A.realp = (float*) malloc(sizeof(float) * dLengthOfFFTData);
    A.imagp = (float*) malloc(sizeof(float) * dLengthOfFFTData);
    
    //Make FFT config
    fftSetup = vDSP_create_fftsetup(log2n, FFT_RADIX2);
    
    
    
    
    
    GraphBufferIndex = 0;
    maxMagnitude = 4.83;
    halfMaxMagnitude = maxMagnitude*0.5;
    //maxMagnitudeOptimized = ;
   // halfMaxMagnitudeOptimized =maxMagnitudeOptimized*0.5;
}


void DSPAnalysis::CalculateDynamicFFT(const float *data, UInt32 numberOfFramesInData, UInt32 whichChannel)
{
    oNumberOfSamplesWhaitingForAnalysis += numberOfFramesInData;
    int numberOfWindowsToAdd = oNumberOfSamplesWhaitingForAnalysis/oNumberOfSamplesBetweenWindows;

    if(numberOfWindowsToAdd==0)
    { //if we don't have enough data
        return;
    }
    
    //Get data from ring buffer
    mExternalRingBuffer->FetchFreshData2(oInputBuffer, oLengthOfWindow, whichChannel , 1);
    float * tempDataBuffer = (float *)calloc(dLengthOfFFTData*2, sizeof(float));
    float zero = 0.0f;
    uint32_t log2n = log2f((float)dLengthOfFFTData);
        
        
    for(int i=0;i<numberOfWindowsToAdd;i++)
    {
        //get data for just one FFT window in small buffer
        vDSP_vsadd((float *)&oInputBuffer[i*oNumberOfSamplesBetweenWindows],
                   downsamplingFactor,
                   &zero,
                   tempDataBuffer,
                   1,
                   dLengthOfFFTData);
        /* Carry out a Forward FFT transform. */
        vDSP_ctoz((COMPLEX *) tempDataBuffer, 2, &A, 1, dLengthOfFFTData);
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
        GraphBufferIndex = (GraphBufferIndex+1)%NumberOfGraphsInBuffer;
    }
    oNumberOfSamplesWhaitingForAnalysis -= numberOfWindowsToAdd*oNumberOfSamplesBetweenWindows;
    
}

void DSPAnalysis::resetFFTMagnitudeBuffer()
{
    //clear all FFT data
    for(int i=0;i<NumberOfGraphsInBuffer;i++)
    {
        for(int k=0;k<LengthOf30HzData;k++)
        {
            FFTDynamicMagnitude[i][k] = -1;
        }
    }
}


void DSPAnalysis::CalculateDynamicFFTDuringSeek(BBAudioFileReader *fileReader, UInt32 numberOfFramesToGet, UInt32 startFrame, UInt32 numberOfChannels, UInt32 whichChannel)
{
    
    oNumberOfSamplesWhaitingForAnalysis = numberOfFramesToGet;
    int numberOfWindowsToAdd = oNumberOfSamplesWhaitingForAnalysis/oNumberOfSamplesBetweenWindows;
    
    //clear all FFT data
    resetFFTMagnitudeBuffer();
    
    if(numberOfWindowsToAdd==0)
    { //if we don't have enough data
        return;
    }
    
    int realBeginingOfDataInFile;
    int realEndOfDataInFile;
    
    //calculate begining of the FFT processing. Starting frame is length of FFT before
    //displayed signal since that is how FFT is processed in live view
    int beginingOfDataInFile = startFrame-oLengthOfWindow;
    //make sure that file reading will end on startFrame + numberOfFramesToGet
    //because we need to finish file reading where raw signal ends
    realEndOfDataInFile =startFrame + numberOfFramesToGet;
    
    //correction for begining of the file where negative index of frame can happen
    realBeginingOfDataInFile = beginingOfDataInFile;
    if(realBeginingOfDataInFile<0)
    {
        realBeginingOfDataInFile = 0;
    }
  
    //difference between real begining of the file and what we need. It has value different than zero
    //if we are at the begining of the file and we need zero padding for FFT
    int differenceInBeginingOfFile = realBeginingOfDataInFile - beginingOfDataInFile;
    
    //make big buffer that will take all data
    float * tempData = (float *)calloc(numberOfChannels*(realEndOfDataInFile-beginingOfDataInFile), sizeof(float));
    //get all data
   
    [fileReader retrieveFreshAudio:&tempData[numberOfChannels*differenceInBeginingOfFile] numFrames:(UInt32)(realEndOfDataInFile-realBeginingOfDataInFile) numChannels:numberOfChannels seek:(UInt32)realBeginingOfDataInFile];
    
    //make small buffer that will hold one window of data for FFT
    float * tempDataBuffer = (float *)calloc(dLengthOfFFTData*2, sizeof(float));
    float zero = 0.0f;

    
    uint32_t log2n = log2f((float)dLengthOfFFTData);
    
    for(int i=0;i<numberOfWindowsToAdd;i++)
    {

        //get data for just one FFT window in small buffer
        vDSP_vsadd((float *)&tempData[i*numberOfChannels*oNumberOfSamplesBetweenWindows+whichChannel],
                   numberOfChannels*downsamplingFactor,
                   &zero,
                   tempDataBuffer,
                   1,
                   dLengthOfFFTData);

        /* Carry out a Forward FFT transform. */
        vDSP_ctoz((COMPLEX *) tempDataBuffer, 2, &A, 1, dLengthOfFFTData);
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
        GraphBufferIndex = (GraphBufferIndex+1)%NumberOfGraphsInBuffer;

    }
    
    oNumberOfSamplesWhaitingForAnalysis -= numberOfWindowsToAdd*oNumberOfSamplesBetweenWindows;
    free(tempDataBuffer);
    free(tempData);
    
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

