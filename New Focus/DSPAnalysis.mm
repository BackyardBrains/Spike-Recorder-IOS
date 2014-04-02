//
//  DSPAnalysis.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/1/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "DSPAnalysis.h"

DSPAnalysis::~DSPAnalysis()
{

}


DSPAnalysis::DSPAnalysis (RingBuffer *externalRingBuffer)
{
	mExternalRingBuffer = externalRingBuffer;
}


float DSPAnalysis::RMSSelection(const float *data, int64_t mSizeOfBuffer)
{
    float rms;
	vDSP_rmsqv(data,1,&rms,mSizeOfBuffer);
	return rms;
}