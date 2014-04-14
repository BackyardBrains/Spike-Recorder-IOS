//
//  DSPAnalysis.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/1/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//
#import <Foundation/Foundation.h>
#include "RingBuffer.h"

class DSPAnalysis {
    
public:
    DSPAnalysis(RingBuffer *externalRingBuffer);
    ~DSPAnalysis();
    float RMSSelection(const float *data, int64_t mSizeOfBuffer);
    
	
private:
	
    RingBuffer *mExternalRingBuffer; // we'll let somebody else keep track of the streaming history
    float startTime;
    float endTime;
};
