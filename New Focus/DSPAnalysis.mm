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
