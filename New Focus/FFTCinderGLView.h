//
//  FFTCinderGLView.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/16/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "CCGLTouchView.h"
#include "cinder/Font.h"
#include "cinder/gl/TextureFont.h"
#include "cinder/Text.h"
#include "cinder/Utilities.h"
#import "BBAudioManager.h"

@interface FFTCinderGLView : CCGLTouchView
{
    CameraOrtho mCam;
    gl::Texture mColorScale;
    gl::TextureFontRef mScaleFont;

    PolyLine2f* displayVectors;
    float baseFreq;
    UInt32 lengthOfFFTData;
    Vec2f scaleXY;//relationship between pixels and GL world (pixels x scaleXY = GL units)
    float maxFreq;
    float maxPow;
    
    float offsetY;
    float currentMaxFreq;
    float currentMaxPow;
    float markIntervalXAxis;
    float retinaCorrection;
    
    BOOL firstDrawAfterChannelChange;
}

-(void) setupWithBaseFreq:(float) inBaseFreq andLengthOfFFT:(UInt32) inLengthOfFFT;
@end
