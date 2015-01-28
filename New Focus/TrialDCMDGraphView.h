//
//  TrialDCMDGraphView.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/15/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "CCGLTouchView.h"
#import "Novocaine.h"
#import "RingBuffer.h"
#import "BBAnalysisManager.h"
#include "cinder/Font.h"
#include "cinder/gl/TextureFont.h"
#include "cinder/Text.h"
#include "cinder/Utilities.h"
#include "BBDCMDTrial.h"


@interface TrialDCMDGraphView : CCGLTouchView
{
    CameraOrtho mCam;
    gl::Texture mColorScale;
    gl::TextureFontRef mScaleFont;
    
    PolyLine2f anglesDisplayVector;
    float * normalizedAngles;
    PolyLine2f averageDisplayVector;
    float * ifrResults;
    Vec2f scaleXY;//relationship between pixels and GL world (pixels x scaleXY = GL units)
    float yOffsetAngles;
    float yOffsetAverage;
    float yOffsetSpikes;
    
    float maxXAxis;
    float minXAxis;
    float maxAverage;
    float maxAngle;
    UInt32 numOfPointsAverage;
    float * gaussKernel;
    float * resultOfWindowing;
    
    BBDCMDTrial * currentTrial;
    BOOL firstDrawAfterChannelChange;
    NSArray * spikesCoordinate;
    float lastRecordedTime;
    float firstAngleTime;
    float retinaCorrection;
}

-(void) createGraphForTrial:(BBDCMDTrial *) trialToGraph;

@end
