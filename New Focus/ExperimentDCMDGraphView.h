//
//  ExperimentDCMDGraphView.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/26/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "CCGLTouchView.h"
#include "cinder/Font.h"
#include "cinder/gl/TextureFont.h"
#include "cinder/Text.h"
#include "cinder/Utilities.h"
#include "BBDCMDTrial.h"
#include "BBDCMDExperiment.h"
@interface ExperimentDCMDGraphView : CCGLTouchView
{
    CameraOrtho mCam;
    gl::Texture mColorScale;
    gl::TextureFontRef mScaleFont;
    

    float * histogramValues;
    float * normalizedHistogramValues;
    float yOffsetHistogram;
    float maxHistogram;
    UInt32 numOfPointsHistogram;
    
    Vec2f scaleXY;//relationship between pixels and GL world (pixels x scaleXY = GL units)

    float maxXAxis;
    float minXAxis;
    
    BBDCMDExperiment * currentExperiment;
    
    BOOL firstDrawAfterChannelChange;
    float retinaCorrection;
    
    NSMutableArray * spikesCoordinatesArray;
    float yOffsetSpikes;
}

-(void) createGraphForExperiment:(BBDCMDExperiment *) experimentToGraph;
@end
