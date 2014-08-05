//
//  DynamicFFTCinderGLView.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/23/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "CCGLTouchView.h"
#include "cinder/Font.h"
#include "cinder/gl/TextureFont.h"
#include "cinder/Text.h"
#include "cinder/Utilities.h"
#import "BBAudioManager.h"

@interface DynamicFFTCinderGLView : CCGLTouchView
{
    CameraOrtho mCam;
    gl::Texture mColorScale;
    gl::TextureFontRef mScaleFont;
    
    PolyLine2f* displayVectors;
    float baseFreq;
    float baseTime;
    UInt32 lengthOfFFTData;
    UInt32 lengthOfFFTBuffer;
    
    Vec2f scaleXY;//relationship between pixels and GL world (pixels x scaleXY = GL units)
    float maxFreq;
    float maxTime;
    
    float offsetY;
    float offsetX;
    float currentMaxFreq;
    float currentMaxTime;
    float markIntervalXAxis;
    float markIntervalYAxis;
    float retinaCorrection;
    
    BOOL firstDrawAfterChannelChange;
}

-(void) setupWithBaseFreq:(float) inBaseFreq lengthOfFFT:(UInt32) inLengthOfFFT numberOfGraphs:(UInt32) inNumOfGraphs maxTime:(float) inMaxTime;

@end
