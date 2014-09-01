//
//  AverageSpikeGraphView.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/27/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "CCGLTouchView.h"
#include "cinder/Font.h"
#include "cinder/gl/TextureFont.h"
#include "cinder/Text.h"
#include "cinder/Utilities.h"
#include "BBFile.h"
#include "BBAnalysisManager.h"
#include "BBChannel.h"


@interface AverageSpikeGraphView : CCGLTouchView
{
    CameraOrtho mCam;
    gl::Texture mColorScale;
    gl::TextureFontRef mScaleFont;
    
    
    AverageSpikeData * spikes; //All data for all spikes
    PolyLine2f tempGraph;
    UInt32 numberOfGraphs;
    UInt32 lengthOfGraphData; //(size of time window) * (sampling rate)
    
    Vec2f scaleXY;//relationship between pixels and GL world (pixels x scaleXY = GL units)
    
    float maxXAxis;
    float minXAxis;
    
    BBFile * currentFile;
    int indexOfChannel;//index of audio channel in file
    float baseYOffset;
    
    BOOL firstDrawAfterChange;
    float retinaCorrection;
}



-(void) createGraphForFile:(BBFile * )newFile andChannelIndex:(int) newChannelIndex;

@end
