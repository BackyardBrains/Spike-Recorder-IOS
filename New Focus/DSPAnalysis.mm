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
}


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
    
    
    fftSetup = vDSP_create_fftsetup(log2n, FFT_RADIX2);
}

float * DSPAnalysis::CalculateFFT(UInt32 whichChannel)
{
    
    mExternalRingBuffer->FetchFreshData2(mInputBuffer, mLengthOfWindow, whichChannel , 1);
    
    uint32_t log2n = log2f((float)mLengthOfWindow);
    /* Carry out a Forward FFT transform. */
    vDSP_ctoz((COMPLEX *) mInputBuffer, 2, &A, 1, LengthOfFFTData);
    vDSP_fft_zrip(fftSetup, &A, 1, log2n, FFT_FORWARD);
    
    
    FFTMagnitude[0] = sqrtf(A.realp[0]*A.realp[0]);
    
    //get magnitude;
    for(int i = 1; i < LengthOfFFTData; i++){
        FFTMagnitude[i] = sqrtf(A.realp[i]*A.realp[i] + A.imagp[i] * A.imagp[i]);
    }

    return FFTMagnitude;
}

//
// Calculate RMS of signal in data
//
float DSPAnalysis::RMSSelection(const float *data, int64_t mSizeOfBuffer)
{
    float rms;
	vDSP_rmsqv(data,1,&rms,mSizeOfBuffer);
	return rms;
}

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
