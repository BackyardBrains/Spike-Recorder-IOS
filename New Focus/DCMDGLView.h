//
//  DCMDGLView.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/7/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "CCGLTouchView.h"
#include "cinder/Font.h"
#include "cinder/gl/TextureFont.h"
#include "cinder/Text.h"
#include "cinder/Utilities.h"
#import "BBDCMDExperiment.h"
#import "BBDCMDTrial.h"

@protocol DCMDGLDelegate;

@interface DCMDGLView : CCGLTouchView
{
    CameraOrtho mCam;
    gl::Texture mColorScale;
    gl::TextureFontRef mScaleFont;
    int trialIndex;
    BBDCMDTrial * currentTrial;
    double   currentTime;
    Vec2f scaleXY;//relationship between pixels and GL world (pixels x scaleXY = GL units)
    double   expStartTime;
    BOOL needStartTime;
    NSMutableArray * trialIndexes;
    float currentSpeed;
    float currentSize;
    int stateOfExp;
    float sizeOnScreen;
    float virtualDistance;
    float angle;
    float maxAngle;
    float startAngle;
    float centerOfScreenX;
    float centerOfScreenY;
    BBDCMDExperiment* _experiment;
    float * sizesForEllipse;
    float radiusXAxis;
    float radiusYAxis;
    Vec2f centerOfScreen;
    int indexOfAngle;
    int maxIndexOfAngleInTrial;
    float pixelsPerMeter;
    BOOL isRotated;
    float retinaPonder;
}

@property (nonatomic, assign) id <DCMDGLDelegate> controllerDelegate;
@property (nonatomic, retain) BBDCMDExperiment* experiment;
- (id)initWithFrame:(CGRect)frame andExperiment:(BBDCMDExperiment *) exp;
- (void) restartCurrentTrial;
-(void) rotated;
-(void) removeAllTrialsThatAreNotSimulated;
@end

@protocol DCMDGLDelegate <NSObject>
-(void) startSavingExperiment;
-(void) endOfExperiment;
-(void) userWantsInterupt;
@end