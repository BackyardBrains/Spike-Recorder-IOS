//
//  DSPAnalysis.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/1/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//
#import <Foundation/Foundation.h>

class DSPAnalysis {
    
public:
    DSPAnalysis();
    ~DSPAnalysis();
    float RMSSelection(const float *data, int64_t mSizeOfBuffer);
    float SDT(const float *data, int64_t mSizeOfBuffer);
	
private:
	
};
