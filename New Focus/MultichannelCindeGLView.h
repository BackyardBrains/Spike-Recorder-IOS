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

	MultichannelGLViewModeThresholding,

	MultichannelGLViewModePlayback,

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
- (float) fetchDataToDisplay:(float *)data numFrames:(UInt32)numFrames whichChannel:(UInt32)whichChannel;

@optional
-(void) removeChannel:(int) chanelIndex;
-(float) getCurrentTimeForSinc;//get current time of audio (used for sync of spikes and waveform)
-(void) selectChannel:(int) selectedChannel;//set selected channel
- (NSMutableArray *) getChannels;//get channels from BBfile object
-(BOOL) shouldEnableSelection;//should view enable interval selection
-(void) updateSelection:(float) newSelectionTime;
-(float) selectionStartTime;
-(float) selectionEndTime;
-(void) endSelection;
-(BOOL) selecting;
-(float) rmsOfSelection;

-(BOOL) thresholding;
-(float) threshold;
- (void)setThreshold:(float)newThreshold;

@end
