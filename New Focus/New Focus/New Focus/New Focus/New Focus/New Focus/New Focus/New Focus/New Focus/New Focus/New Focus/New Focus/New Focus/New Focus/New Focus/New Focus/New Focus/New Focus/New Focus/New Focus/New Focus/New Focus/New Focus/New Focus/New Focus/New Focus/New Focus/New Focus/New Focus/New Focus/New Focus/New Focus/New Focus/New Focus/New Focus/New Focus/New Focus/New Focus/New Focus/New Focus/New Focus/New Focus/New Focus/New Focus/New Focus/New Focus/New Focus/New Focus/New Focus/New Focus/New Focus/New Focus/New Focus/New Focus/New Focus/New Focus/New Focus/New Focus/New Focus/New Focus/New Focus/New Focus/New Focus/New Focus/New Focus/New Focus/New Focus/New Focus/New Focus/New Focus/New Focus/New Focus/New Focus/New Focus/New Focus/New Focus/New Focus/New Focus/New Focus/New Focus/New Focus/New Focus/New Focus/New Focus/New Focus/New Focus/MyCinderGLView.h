//
//  MyCinderGLView.h
//  CCGLTouchBasic example
//
//  Created by Matthieu Savary on 09/09/11.
//  Copyright (c) 2011 SMALLAB.ORG. All rights reserved.
//
//  More info on the CCGLTouch project >> http://www.smallab.org/code/ccgl-touch/
//  License & disclaimer >> see license.txt file included in the distribution package
//

#import "CCGLTouchView.h"
#import "Novocaine.h"
#import "RingBuffer.h"
#import "AudioFileWriter.h"
#import "BBAudioManager.h"
#include "cinder/Font.h"
#include "cinder/gl/TextureFont.h"
#include "cinder/Text.h"
#include "cinder/Utilities.h"


@interface MyCinderGLView : CCGLTouchView {
    CameraOrtho mCam;
    gl::Texture mColorScale;
    gl::TextureFontRef mScaleFont;
    
    RingBuffer *ringBuffer;
    AudioFileWriter *fileWriter;
    
    PolyLine2f displayVector;
    
    // Display parameters
    float numSecondsMax;
    float numSecondsMin;
    float numSecondsVisible;
    
    float numVoltsMax;
    float numVoltsMin;
    float numVoltsVisible;
    
    BOOL stimulating;
    BOOL recording;
}

/**
 *  incoming from controller
 */

@property (nonatomic) BOOL stimulating;
@property (nonatomic) BOOL recording;


- (void)setRecording:(BOOL)recordOrNot;
- (void)setStimulating:(BOOL)stimulateOrNot;
- (void)saveSettings:(BOOL)useThresholdSettings;
- (void)loadSettings:(BOOL)useThresholdSettings;

@end
