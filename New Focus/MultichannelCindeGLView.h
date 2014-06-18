//
//  MultichannelCindeGLView.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 5/28/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "CCGLTouchView.h"
#include "cinder/Font.h"
#include "cinder/gl/TextureFont.h"
#include "cinder/Text.h"
#include "cinder/Utilities.h"

@protocol MultichannelGLViewDelegate ;


typedef enum {
    MultichannelGLViewModeView,
	//Progress is shown using an UIActivityIndicatorView. This is the default.
	MultichannelGLViewModeThresholding,
	//Progress is shown using a round, pie-chart like, progress view.
	MultichannelGLViewModePlayback,
	//Progress is shown using a horizontal progress bar
	MultichannelGLViewModeDeterminateHorizontalBar
} MultichannelGLViewMode;


@interface MultichannelCindeGLView : CCGLTouchView
{
    CameraOrtho mCam;
    gl::Texture mColorScale;
    gl::TextureFontRef mScaleFont;

    id <MultichannelGLViewDelegate> dataSourceDelegate;
    PolyLine2f* displayVectors;
    
    float samplingRate;
    int numberOfChannels;

    // Display parameters
    int numSamplesMax;
    int numSamplesMin;
    float numSamplesVisible; //current zoom for every channel x axis

    float numVoltsMax;
    float numVoltsMin;
    float* numVoltsVisible; //current zoom for every channel y axis
    
    float* yOffsets; //current offsets for all channels
    
}


@property (assign) MultichannelGLViewMode mode;

- (void)saveSettings:(BOOL)useThresholdSettings;
- (void)loadSettings:(BOOL)useThresholdSettings;
- (void)setNumberOfChannels:(int) newNumberOfChannels samplingRate:(float) newSamplingRate andDataSource:(id <MultichannelGLViewDelegate>) newDataSource;

@end


/**
    This protocol should be implemented by every data source that wants to display data on this GL view
 */
@protocol MultichannelGLViewDelegate <NSObject>
//Called every frame when view needs data to display
- (void) fetchDataToDisplay:(float *)data numFrames:(UInt32)numFrames whichChannel:(UInt32)whichChannel;

@optional

-(void) selectChannel:(int) selectedChannel;

@end
