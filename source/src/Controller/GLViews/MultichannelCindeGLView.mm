//
//  MultichannelCindeGLView.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 5/28/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "MultichannelCindeGLView.h"
#import <Accelerate/Accelerate.h>
#import "BBSpike.h"
#import "BBSpikeTrain.h"
#import "BBChannel.h"
#import "BBBTManager.h"
#import "BBAudioManager.h"
#define HANDLE_RADIUS 20

#define MAX_THRESHOLD_VISIBLE_TIME 1.5
#define HIDE_HANDLES_AFTER_SECONDS 4.0
#define MAXIMUM_POSITION_OF_HANDLES -5.6


@interface MultichannelCindeGLView ()
{
   
    float * tempDataBuffer; //data buffer that is used to transfer data (modify stride) to displayVectors
    int selectedChannel;//current selected channel
    float maxTimeSpan;//max time
    float maxVoltsSpan;//max volts
    BOOL multichannel;//flag for multichannel logic
   
    //precalculated constants
    Vec2f scaleXY;//relationship between pixels and GL world (pixels x scaleXY = GL units)
 
    float timeForSincDrawing;
    BOOL weAreDrawingSelection;
    //debug variables
   // BOOL debugMultichannelOnSingleChannel;
    BOOL firstDrawAfterChannelChange;
    
    NSTimeInterval lastUserInteraction;//last time user taped screen
    NSTimeInterval currentUserInteractionTime;//temp variable for calculation
    BOOL handlesShouldBeVisible;
    float offsetPositionOfHandles;
    
    float xPositionOfRemove;
    float yPositionOfRemove;
    
    bool selectionEnabledAfterSecond;
    
    //detect touch 1s
    NSTimer * touchTimer;
    float startY;
    float startX;
    float timePos;
    
    //scrubbing on waveform
    BOOL playerWasPlayingWhenStoped;
    float lastXPosition;
    int frameCount;
    
}

@end


@implementation MultichannelCindeGLView

@synthesize mode;//operational mode - enum MultichannelGLViewMode
@synthesize channelsConfiguration;
//====================================== INIT ==============================================================================
#pragma mark - Initialization
//
// Called by super on initWithFrame. It will start animation.
//
- (void)setup
{
    //debugMultichannelOnSingleChannel = NO;
    weAreDrawingSelection = NO;
    frameCount = 0;
    dataSourceDelegate = nil;
    samplingRate = 0;
    numberOfChannels = 0;
    [self enableMultiTouch:YES];
    
    multichannel = NO;
    
    [super setup];//this calls [self startAnimation]
 
    // Setup the camera
	mCam.lookAt( Vec3f(0.0f, 0.0f, 40.0f), Vec3f::zero() );
    
    [self enableAntiAliasing:YES];
    
    // Make sure that we can autorotate 'n what not.
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    // Set up our font, which we'll use to display the unit scales
    
  
    
   
    mFont = Font("Helvetica", 18);
    mScaleFont = gl::TextureFont::create( mFont );
    
    lastUserInteraction = [[NSDate date] timeIntervalSince1970];
    handlesShouldBeVisible = NO;
    offsetPositionOfHandles = 0;
    selectionEnabledAfterSecond = false;
    
}


//
// Function setup view to display newNumberOfChannels channels with samling rate of newSamplingRate and
// it will get data using MultichannelGLViewDelegate protocol from newDataSource.
//
- (void)setNumberOfChannels:(int) newNumberOfChannels samplingRate:(float) newSamplingRate andDataSource:(id <MultichannelGLViewDelegate>) newDataSource
{
    
    if([[BBAudioManager bbAudioManager] btOn])
    {
        maxNumberOfChannels = [[BBBTManager btManager] maxNumberOfChannelsForDevice];
    }
    else
    {
        maxNumberOfChannels = newNumberOfChannels;
    }
    
    firstDrawAfterChannelChange = YES;
    NSLog(@"!!!!!!!!!Setup num of channel");
    [self stopAnimation];
    
  //  if(newNumberOfChannels<2)
  //  {
  //      debugMultichannelOnSingleChannel = YES;
  //      newNumberOfChannels = 3;
  //  }
    
    
    samplingRate = newSamplingRate;
    numberOfChannels = newNumberOfChannels;
    
    if(numberOfChannels>1)
    {
        multichannel = YES;
    }
    
    
    // Setup display vectors. Every PolyLine2f is one waveform
    if(displayVectors!=nil)
    {
        //TODO: realease display vectors
        delete[] displayVectors;
        delete[] numVoltsVisible;
        //delete[] yOffsets;
        delete[] tempDataBuffer;
    }
    displayVectors =  new PolyLine2f[newNumberOfChannels];
    numVoltsVisible = new float[maxNumberOfChannels]; //current zoom for every channel y axis
    
    if(!yOffsets)
    {
        yOffsets = new float[maxNumberOfChannels];//y offset of horizontal axis
    }
   
    
    //load limits for graph and init starting position
   
    [self loadSettings:mode==MultichannelGLViewModeThresholding];
    
    
    //data buffer that is used to transfer data (modify stride) to displayVectors
    tempDataBuffer = new float[numSamplesMax];

    maxTimeSpan = ((float)numSamplesMax)/newSamplingRate;

    //4 milivolts will be screen size
    maxVoltsSpan = 0.008;
    
    
    //create vetors that hold waveforms for every channel
    //we will create X axis values now and afterwards we will change Y values in every frame
    // and X axis values on zoom in/ zoom out
    
    scaleXY = [self screenToWorld:Vec2f(1.0f,1.0f)];
    Vec2f scaleXYZero = [self screenToWorld:Vec2f(0.0f,0.0f)];
    scaleXY.x = fabsf(scaleXY.x - scaleXYZero.x);
    scaleXY.y = fabsf(scaleXY.y - scaleXYZero.y);
    float usableYAxisSpan = maxVoltsSpan*0.8;
    
    for(int channelIndex = 0; channelIndex < numberOfChannels; channelIndex++)
    {
        
        float oneSampleTime = maxTimeSpan / numSamplesVisible;
        for (int i=0; i <numSamplesMax-1; i++)
        {
            float x = (i- (numSamplesMax-1))*oneSampleTime;
            displayVectors[channelIndex].push_back(Vec2f(x, 0.0f));
        }
        displayVectors[channelIndex].setClosed(false);
        //make some vertical space between channels
        
        
    }

    for(int channelIndex = 0; channelIndex < maxNumberOfChannels; channelIndex++)
    {
        if(yOffsets[channelIndex]==0.0f)
        {
            yOffsets[channelIndex] = -usableYAxisSpan*0.4 + (channelIndex+1)*(usableYAxisSpan/((float)maxNumberOfChannels))- 0.5*(usableYAxisSpan/((float)maxNumberOfChannels));
        }
    }
    if(maxNumberOfChannels==1)
    {
        yOffsets[0] = 0.0f;
    }
    
    dataSourceDelegate = newDataSource;
    
    if([[BBAudioManager bbAudioManager] btOn])
    {
        channelsConfiguration = [[BBBTManager btManager] activeChannels];
    }
    else
    {
        int tempMask = 1;
        channelsConfiguration = 0;
        for(int k=0;k<[[BBAudioManager bbAudioManager] sourceNumberOfChannels];k++)
        {
            channelsConfiguration = channelsConfiguration | (tempMask<<k);
        }
    }
    
    for(int i=0;i<maxNumberOfChannels;i++)
    {
        if([self channelActive:i])
        {
            selectedChannel = i;
            break;
        }
    }
    
    if ([dataSourceDelegate respondsToSelector:@selector(selectChannel:)]) {
        [dataSourceDelegate selectChannel:0];
    }
    
    NSLog(@"End setup number of channels");
    [self startAnimation];
    
}


-(float *) getChannelOffsets
{
    float* tempCO = new float[maxNumberOfChannels];
    for(int i=0;i<maxNumberOfChannels;i++)
    {
        tempCO[i] =yOffsets[i];
    }
    return tempCO;
}


-(void) setChannelOffsets:(float *) tempChannelOffsets
{
    
    for(int i=0;i<maxNumberOfChannels;i++)
    {
        yOffsets[i] = tempChannelOffsets[i];
    }
    
}

//
// Check if channel is active\
// channels configuration keeps info about active
// and nonactive channels. Every channel is one bit.
// if it is active than bit is set to 1 if not to 0
//
-(BOOL) channelActive:(UInt8) channelIndex
{
    if(channelIndex>maxNumberOfChannels)
    {
        return NO;
    }
    int tempMask = 1;
    tempMask = tempMask<<channelIndex;
    return ((channelsConfiguration & tempMask) > 0);
}


- (void)dealloc
{
    mScaleFont = nil;
    if(displayVectors!=nil)
    {
        delete[] displayVectors;
        delete[] numVoltsVisible;
        //delete[] yOffsets;
        delete[] tempDataBuffer;
    }
    [super dealloc];
}



- (void)loadSettings:(BOOL)useThresholdSettings
{
    
    NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Initialize parameters
    if (useThresholdSettings) {
        NSLog(@"Setting threshold defaults");
        numSamplesMax = [[defaults valueForKey:@"numSamplesMaxThreshold"] floatValue];
        numSamplesMin = [[defaults valueForKey:@"numSamplesMin"] floatValue];
        numSamplesVisible = [[defaults valueForKey:@"numSamplesVisibleThreshold"] floatValue];
        if(numSamplesVisible>MAX_THRESHOLD_VISIBLE_TIME*samplingRate)
        {
            numSamplesVisible = MAX_THRESHOLD_VISIBLE_TIME*samplingRate;
        }
        numVoltsMin = [[defaults valueForKey:@"numVoltsMinThreshold"] floatValue];
        numVoltsMax = [[defaults valueForKey:@"numVoltsMaxThreshold"] floatValue];
       
        for(int i=0;i<maxNumberOfChannels;i++)
        {
            numVoltsVisible[i] = [[defaults valueForKey:@"numVoltsVisibleThreshold"] floatValue];
            NSLog(@"Max volts visible: %f", numVoltsVisible[i]);
            if(numVoltsVisible[i] < 0.001)
            {
                numVoltsVisible[i] = 0.002;
            }
            if(numVoltsVisible[i]>numVoltsMax)
            {
                numVoltsVisible[i] = numVoltsMax;
            }
        }
    }
    else {
        numSamplesMax = [[defaults valueForKey:@"numSamplesMax"] floatValue];
        numSamplesMin = [[defaults valueForKey:@"numSamplesMin"] floatValue];
        numSamplesVisible = [[defaults valueForKey:@"numSamplesVisible"] floatValue];
        numVoltsMin = [[defaults valueForKey:@"numVoltsMin"] floatValue];
        numVoltsMax = [[defaults valueForKey:@"numVoltsMax"] floatValue];
        
        for(int i=0;i<maxNumberOfChannels;i++)
        {
            numVoltsVisible[i] = [[defaults valueForKey:@"numVoltsVisible"] floatValue];
             NSLog(@"Max volts visible: %f", numVoltsVisible[i]);
            if(numVoltsVisible[i]>numVoltsMax)
            {
                numVoltsVisible[i] = numVoltsMax;
            }
            if(numVoltsVisible[i] < 0.001)
            {
                numVoltsVisible[i] = 0.002;
            }
        }
        
    }
    
}

- (void)saveSettings:(BOOL)useThresholdSettings
{
    NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Save parameters
    // Initialize parameters
    if (useThresholdSettings) {
        [defaults setValue:[NSNumber numberWithFloat:numSamplesMax] forKey:@"numSamplesMaxThreshold"];
        [defaults setValue:[NSNumber numberWithFloat:numSamplesMin] forKey:@"numSamplesMin"];
        [defaults setValue:[NSNumber numberWithFloat:numSamplesVisible] forKey:@"numSamplesVisibleThreshold"];
        [defaults setValue:[NSNumber numberWithFloat:numVoltsMin] forKey:@"numVoltsMinThreshold"];
        
        [defaults setValue:[NSNumber numberWithFloat:numVoltsMax] forKey:@"numVoltsMaxThreshold"];
        if(numVoltsVisible[0]>numVoltsMax)
        {
            numVoltsVisible[0] = numVoltsMax;
        }
        [defaults setValue:[NSNumber numberWithFloat:numVoltsVisible[0]] forKey:@"numVoltsVisibleThreshold"];
    }
    else {
        [defaults setValue:[NSNumber numberWithFloat:numSamplesMax] forKey:@"numSamplesMax"];
        [defaults setValue:[NSNumber numberWithFloat:numSamplesMin] forKey:@"numSamplesMin"];
        [defaults setValue:[NSNumber numberWithFloat:numSamplesVisible] forKey:@"numSamplesVisible"];
        [defaults setValue:[NSNumber numberWithFloat:numVoltsMin] forKey:@"numVoltsMin"];
        [defaults setValue:[NSNumber numberWithFloat:numVoltsMax] forKey:@"numVoltsMax"];
        if(numVoltsVisible[0]>numVoltsMax)
        {
            numVoltsVisible[0] = numVoltsMax;
        }
        [defaults setValue:[NSNumber numberWithFloat:numVoltsVisible[0]] forKey:@"numVoltsVisible"];
    }
    
    [defaults synchronize];
}

//====================================== PERIODIC ==============================================================================

#pragma mark - Periodic stuff


//
// Get Y axis data for all channels
//
- (void)fillDisplayVector
{
    
    // We'll be checking if we have to limit the amount of points we display on the screen
    // (e.g., the user is allowed to pinch beyond the maximum allowed range, but we
    // just display what's available, and then stretch it back to the true limit)
    //for(int channelIndex = 0; channelIndex<numberOfChannels; channelIndex++)
    //{
        // See if we're asking for TOO MANY points
        int numPoints, offset;
        if (numSamplesVisible > numSamplesMax) {
            numPoints = numSamplesMax-1;
            offset = 0;
            
            if ([self getActiveTouches].size() != 2)
            {
                float oldValue = numSamplesVisible;
                numSamplesVisible += 0.6 * (numSamplesMax-1 - numSamplesVisible);
                
                float zero = 0.0f;
                float zoom = oldValue/numSamplesVisible;
                int realIndexOfChannel = 0;
                for(int channelIndex = 0; channelIndex<maxNumberOfChannels; channelIndex++)
                {
                    if([self channelActive:channelIndex])
                    {
                        vDSP_vsmsa ((float *)&(displayVectors[realIndexOfChannel].getPoints()[0]), 2,
                            &zoom,
                            &zero,
                            (float *)&(displayVectors[realIndexOfChannel].getPoints()[0]),
                            2,
                            numSamplesMax
                            );
                        realIndexOfChannel ++;
                    }
                }
            }
        }
        
        // See if we're asking for TOO FEW points
        else if (numSamplesVisible < numSamplesMin)
        {
            
            numPoints = numSamplesMin;
            offset = 0;
            
            if ([self getActiveTouches].size() != 2)
            {
                
                float oldValue = numSamplesVisible;
                numSamplesVisible += 0.6 * (numSamplesMin*2.0 - numSamplesVisible);//animation to min sec
                
                float zero = 0.0f;
                float zoom = oldValue/numSamplesVisible;
                int realIndexOfChannel = 0;
                for(int channelIndex = 0; channelIndex<numberOfChannels; channelIndex++)
                {
                    if([self channelActive:channelIndex])
                    {
                        vDSP_vsmsa ((float *)&(displayVectors[realIndexOfChannel].getPoints()[0]), 2,
                                &zoom,
                                &zero,
                                (float *)&(displayVectors[realIndexOfChannel].getPoints()[0]),
                                2,
                                numSamplesMax
                                );
                        realIndexOfChannel++;
                    }
                }

            }
        }
        
        // If we haven't set off any of the alarms above,
        // then we're asking for a normal range of points.
        else {
            numPoints = numSamplesVisible+1;//visible part
            offset = numSamplesMax - numPoints-1;//nonvisible part
            if(offset<0)
            {
                offset = 0;
            }
        }
    
        if(numPoints>numSamplesMax)
        {
            numPoints = numSamplesMax;
            offset = 0;
        }
    
        // Aight, now that we've got our ranges correct, let's ask for the signal.
        //Only fetch visible part (numPoints samples) and put it after offset.

    int realIndexOfChannel = 0;
    for(int channelIndex = 0; channelIndex<maxNumberOfChannels; channelIndex++)
    {
        if([self channelActive:channelIndex])
        {
            if (!(mode == MultichannelGLViewModeThresholding))
            {
                numPoints = numSamplesMax;
                offset = 0;
            }
        
            timeForSincDrawing =  [dataSourceDelegate fetchDataToDisplay:tempDataBuffer numFrames:numPoints whichChannel:realIndexOfChannel];
            
            float zero = yOffsets[channelIndex];
            float zoom = maxVoltsSpan/ numVoltsVisible[channelIndex];
            //float zoom = 1.0f;
            vDSP_vsmsa (tempDataBuffer,
                        1,
                        &zoom,
                        &zero,
                        (float *)&(displayVectors[realIndexOfChannel].getPoints()[offset])+1,
                        2,
                        numPoints
                        );
            realIndexOfChannel++;
        }
        
    }
}



- (void)draw {
    
    if(dataSourceDelegate)
    {
        
        if(firstDrawAfterChannelChange )
        {
            frameCount++;
            //this is fix for bug. Draw text starts to paint background of text
            //to the same color as text if we don't make new instance here
            //TODO: find a reason for this
           // mScaleFont = nil;
            if(frameCount>4)
            {
                firstDrawAfterChannelChange = NO;
            }
            //mFont = Font("Helvetica", 18);
            mScaleFont = gl::TextureFont::create( mFont );
           // mScaleFont = gl::TextureFont::create( mFont );
          //  mScaleFont->create(mFont);
        }
        
        currentUserInteractionTime = [[NSDate date] timeIntervalSince1970];
        handlesShouldBeVisible = (currentUserInteractionTime-lastUserInteraction)<HIDE_HANDLES_AFTER_SECONDS;
        
        //mScaleFont = gl::TextureFont::create( Font("Helvetica", 18) );
        // this pair of lines is the standard way to clear the screen in OpenGL
        gl::clear( Color( 0.0f, 0.0f, 0.0f ), true );
        glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
        // Look at it right
        //+(((float)maxTimeSpan)/(float)numSamplesVisible)
        mCam.setOrtho(-maxTimeSpan, -0.0f, -maxVoltsSpan/2.0f, maxVoltsSpan/2.0f, 1, 100);
        gl::setMatrices( mCam );
        
        scaleXY = [self screenToWorld:Vec2f(1.0f,1.0f)];
        Vec2f scaleXYZero = [self screenToWorld:Vec2f(0.0f,0.0f)];
        scaleXY.x = fabsf(scaleXY.x - scaleXYZero.x);
        scaleXY.y = fabsf(scaleXY.y - scaleXYZero.y);

        //mCam.setOrtho(-maxTimeSpan*2, maxTimeSpan, -maxVoltsSpan/2.0f, maxVoltsSpan/2.0f, 1, 100);
        //gl::setMatrices( mCam );
        
        if ([dataSourceDelegate respondsToSelector:@selector(selecting)])
        {
            weAreDrawingSelection = [dataSourceDelegate shouldEnableSelection] && [dataSourceDelegate selecting] &&  [dataSourceDelegate selectionStartTime] != [dataSourceDelegate selectionEndTime] ;
            if(weAreDrawingSelection)
            {
                [self drawSelectionInterval];
            }
        }
        
        // Set the line color and width
        glColor4f(0.0f, 1.0f, 0.0f, 1.0f);
        glLineWidth(2.0f);
        
        // Put the audio on the screen
        gl::disableDepthRead();
        if([[BBAudioManager bbAudioManager] rtSpikeSorting])
        {
            [self drawRTSpikes];
        }
        [self fillDisplayVector];

        int realIndexOfChannel = 0;
        for(int channelIndex=0;channelIndex<maxNumberOfChannels;channelIndex++)
        {
            if([self channelActive:channelIndex])
            {
                [self setColorWithIndex:channelIndex transparency:1.0f];
                gl::draw(displayVectors[realIndexOfChannel]);
                realIndexOfChannel++;
            }

        }

        //Draw spikes
        glLineWidth(1.0f);
        if(self.mode == MultichannelGLViewModePlayback)
        {
            [self drawSpikes];
        }
        

        
        //Draw handlws for movement of axis
        if(multichannel || self.mode == MultichannelGLViewModeView)
        {
            //draw handle
            
            [self drawHandles];
            
        }
        
        
        if([dataSourceDelegate respondsToSelector:@selector(thresholding)])
        {
            // Draw a threshold line, if we're thresholding
            [self drawThreshold];
        }
        

        //Draw measurements on screen
        if(weAreDrawingSelection)
        {
            [self drawTimeAndRMS];
        }
        else
        {
            // Put a time scale
            [self drawGrid];
            // Draw scale on the screen
            [self drawScaleText];
        }
    }
    //glColor4f(1.0f, 1.0f, 0.0f, 1.0f);
}


-(void) drawThreshold
{
    if ([dataSourceDelegate thresholding]) {
        glColor4f(1.0, 0.0, 0.0, 1.0);
        glLineWidth(1.0f);
        float zoom = maxVoltsSpan/ numVoltsVisible[selectedChannel];
        // Draw a line from left to right at the voltage threshold value.
        float threshval = yOffsets[selectedChannel]+[dataSourceDelegate threshold]*zoom;

        float centerOfCircleX = -20*scaleXY.x;
        
        float radiusXAxis = HANDLE_RADIUS*scaleXY.x;
        float radiusYAxis = HANDLE_RADIUS*scaleXY.y;
        
        //draw all handles

        gl::drawSolidEllipse( Vec2f(centerOfCircleX, threshval), radiusXAxis, radiusYAxis, 100 );
        gl::drawSolidTriangle(
                              Vec2f(centerOfCircleX-0.35*radiusXAxis, threshval+radiusYAxis*0.97),
                              Vec2f(centerOfCircleX-1.6*radiusXAxis, threshval),
                              Vec2f(centerOfCircleX-0.35*radiusXAxis, threshval-radiusYAxis*0.97)
                              );
        
        glLineWidth(2.0f);
        float linePart = radiusXAxis*0.7;
        for(float pos=-maxTimeSpan;pos<-linePart; pos+=linePart+linePart)
        {
            gl::drawLine(Vec2f(pos, threshval), Vec2f(pos+linePart, threshval));
        }
        
       /* if(numberOfChannels==1)
        {
            [self setColorWithIndex:0 transparency:1.0f];
            gl::drawLine(Vec2f(-maxTimeSpan, yOffsets[selectedChannel]), Vec2f(0, yOffsets[selectedChannel]));
        }*/
        
        //gl::drawLine(Vec2f(centerOfCircleX, threshval), Vec2f(-maxTimeSpan, threshval));
        glLineWidth(1.0f);
    }
}

-(void) drawTimeAndRMS
{
    // Draw selection area
    std::stringstream timeStream;
    std::stringstream rmstream;
    float sStartTime;
    float sEndTime;
    //Order time points in right way
    
    if([dataSourceDelegate selectionStartTime]>[dataSourceDelegate selectionEndTime])
    {
        sStartTime = [dataSourceDelegate selectionEndTime];
        sEndTime = [dataSourceDelegate selectionStartTime];
    }
    else
    {
        sStartTime = [dataSourceDelegate selectionStartTime];
        sEndTime = [dataSourceDelegate selectionEndTime];
    }

    
    //Calculate time
    float timeToDisplay = 1000.0*(sEndTime - sStartTime);
    
    timeStream.precision(1);
    if (timeToDisplay >= 1000) {
        timeToDisplay /= 1000.0;
        timeStream << fixed << timeToDisplay << " s";
    }
    else {
        timeStream << fixed << timeToDisplay << " msec";
    }
    
    //Get RMS string
    float rmsToDisplay = [dataSourceDelegate rmsOfSelection];
    
    rmstream.precision(3);
    rmstream <<"RMS: "<< fixed << rmsToDisplay << " mV";
    
    
    
    
    gl::disableDepthRead();
    gl::setMatricesWindow( Vec2i(self.frame.size.width, self.frame.size.height) );
	gl::enableAlphaBlending();
    
  
    
	gl::color( ColorA( 1.0, 1.0f, 1.0f, 1.0f ) );
    
 
    
    
      //Draw time ---------------------------------------------
    
    //if we are measuring draw measure result at the bottom
    Vec2f xScaleTextSize = mScaleFont->measureString(timeStream.str());
    Vec2f xScaleTextPosition = Vec2f(0.,0.);
    xScaleTextPosition.x = (self.frame.size.width - xScaleTextSize.x)/2.0;
    //if it is iPad put somewhat higher
    
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        xScaleTextPosition.y =0.85*self.frame.size.height + (mScaleFont->getAscent() / 2.0f);
    }
    else
    {
        xScaleTextPosition.y =0.923*self.frame.size.height + (mScaleFont->getAscent() / 2.0f);
    }
    glColor4f(0.0, 0.47843137254901963, 1.0, 1.0);
    float centerx = self.frame.size.width/2;
    
    //draw background rectangle
    gl::enableDepthRead();
    gl::drawSolidRect(Rectf(centerx-3*xScaleTextSize.y,xScaleTextPosition.y-1.1*xScaleTextSize.y,centerx+3*xScaleTextSize.y,xScaleTextPosition.y+0.4*xScaleTextSize.y));
    gl::disableDepthRead();
    gl::color( ColorA( 1.0, 1.0f, 1.0f, 1.0f ) );
    //draw text
    mScaleFont->drawString(timeStream.str(), xScaleTextPosition);
    
    
    //Draw RMS -------------------------------------------------
    

    
    
    
    Vec2f textSize = mScaleFont->measureString(rmstream.str());
    
    float widthOfBackground = 160;// *scaleXY.x;
    float paddingOfBackground = 10;// * scaleXY.x;
    float heightOfOneRow = textSize.y * 1.4f;// * scaleXY.y;
    float rowVerticalGap = 4;// * scaleXY.x;
    
    float xPositionOfBackground = self.frame.size.width-widthOfBackground-paddingOfBackground;
    float yPositionOfBackground = 100;
    
    
    float xpositionOfCenterOfRMSBackground = xPositionOfBackground+widthOfBackground*0.5;
    Vec2f textPosition = Vec2f(0.,0.);
    textPosition.x = (xpositionOfCenterOfRMSBackground - 0.5*textSize.x);
    textPosition.y = yPositionOfBackground +heightOfOneRow - 0.4*(textSize.y);
    //if it is iPad put it on the right
   /* UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad || UIInterfaceOrientationIsLandscape(interfaceOrientation)) {
        rmsTextPosition.y =xScaleTextPosition.y;
    }
    else
    {
        rmsTextPosition.y =0.23*self.frame.size.height + (mScaleFont->getAscent() / 2.0f);
    }
    */
    glColor4f(0.0, 0.0, 0.0, 1.0);
    
    
    //draw background rectangle
    gl::drawSolidRect(Rectf(xPositionOfBackground, yPositionOfBackground, xPositionOfBackground+widthOfBackground, yPositionOfBackground+heightOfOneRow));
    
    //draw text
    gl::color( ColorA( 0.0, 1.0f, 0.0f, 1.0f ) );
    mScaleFont->drawString(rmstream.str(), textPosition);

    
    
    //Draw Spike count -----------------------------------------
    
    if(self.mode == MultichannelGLViewModePlayback)
    {
        NSMutableArray * spikeCountArray = [dataSourceDelegate spikesCount];
        
        int i;
        BOOL hasSomeSpikes;
        hasSomeSpikes = YES;
        for(i=0;i<[spikeCountArray count];i++)
        {
            if([[spikeCountArray objectAtIndex:i] integerValue]>0)
            {
                hasSomeSpikes = YES;
                break;
            }
            i++;
        }
        
        rmstream.precision(1);
        //Draw spike count
        if(hasSomeSpikes)
        {
            for(i=0;i<[spikeCountArray count];i=i+2)//in array we have pairs. First is count of spikes and second is ISI based frequency
            {
                //change vertical position of label
                yPositionOfBackground = yPositionOfBackground-heightOfOneRow-rowVerticalGap;
                
                //get spike count and frequency
                int cSpikeCount = [[spikeCountArray objectAtIndex:i] integerValue];
                //in array we have pairs. First is count of spikes and second is ISI based frequency
                float cSpikeFrequency =[[spikeCountArray objectAtIndex:i+1] floatValue];
                
                //create string and measure size
                rmstream.str("");
                rmstream << fixed << (int)cSpikeCount<< "("<<cSpikeFrequency<<"Hz)";
                textSize = mScaleFont->measureString(rmstream.str());

                //draw background rectangle
                glColor4f(0.0, 0.0, 0.0, 1.0);
                gl::drawSolidRect(Rectf(xPositionOfBackground, yPositionOfBackground, xPositionOfBackground+widthOfBackground, yPositionOfBackground+heightOfOneRow));
                
                
                float xpositionOfCenterOfSpikesBackground = xPositionOfBackground+widthOfBackground*0.5;
               
                textPosition.x = (xpositionOfCenterOfSpikesBackground - 0.5*textSize.x);
                textPosition.y = yPositionOfBackground +heightOfOneRow - 0.4*(textSize.y);
                
                
                //draw text
                gl::color( ColorA( 0.0, 1.0f, 0.0f, 1.0f ) );
                mScaleFont->drawString(rmstream.str(), textPosition);
            
                //[self setColorWithIndex:i transparency:1.0f];
                [self setGLColor:[BYBGLView getSpikeTrainColorWithIndex:i/2 transparency:1.0f]];
                gl::drawSolidEllipse( Vec2f(xPositionOfBackground+10, yPositionOfBackground+heightOfOneRow*0.5), 5,5, 40 );
                
            }
        }
    
    }

}


-(void) drawSelectionInterval
{

        glLineWidth(1.0f);
    
        float sStartTime;
        float sEndTime;
        //Order time points in right way
    
        if([dataSourceDelegate selectionStartTime]>[dataSourceDelegate selectionEndTime])
        {
            sStartTime = [dataSourceDelegate selectionEndTime];
            sEndTime = [dataSourceDelegate selectionStartTime];
        }
        else
        {
            sStartTime = [dataSourceDelegate selectionStartTime];
            sEndTime = [dataSourceDelegate selectionEndTime];
        }
        float virtualVisibleTimeSpan = numSamplesVisible * 1.0f/samplingRate;
        sStartTime = (sStartTime/virtualVisibleTimeSpan)*(-maxTimeSpan);
        sEndTime = (sEndTime/virtualVisibleTimeSpan)*(-maxTimeSpan);
    
        //draw background of selected region
        glColor4f(0.4, 0.4, 0.4, 0.5);
        gl::disableDepthRead();
        gl::drawSolidRect(Rectf(sStartTime, -maxVoltsSpan/2, sEndTime, maxVoltsSpan/2),false);
        
        //draw limit lines
        glColor4f(0.8, 0.8, 0.8, 1.0);
        gl::drawLine(Vec2f(sStartTime, -maxVoltsSpan/2), Vec2f(sStartTime, maxVoltsSpan/2));
        gl::drawLine(Vec2f(sEndTime, -maxVoltsSpan/2), Vec2f(sEndTime, maxVoltsSpan/2));
        gl::enableDepthRead();
}

//
// Draw handles for axis
//
-(void) drawHandles
{
    float centerOfCircleX = -maxTimeSpan+20*scaleXY.x;

    float radiusXAxis = HANDLE_RADIUS*scaleXY.x;
    float radiusYAxis = HANDLE_RADIUS*scaleXY.y;
    float transparencyForAxis = 1.0f;
    
    //hide/show animation of handles
    if(handlesShouldBeVisible)
    {
        offsetPositionOfHandles+=radiusXAxis/3.0;
        if(offsetPositionOfHandles>0.0)
        {
            offsetPositionOfHandles = 0.0;
        }
    }
    else
    {
        offsetPositionOfHandles-=radiusXAxis/5.0;
        if(offsetPositionOfHandles<MAXIMUM_POSITION_OF_HANDLES*radiusXAxis)
        {
            offsetPositionOfHandles = MAXIMUM_POSITION_OF_HANDLES*radiusXAxis;
        }
    }
    transparencyForAxis = 1.0f - offsetPositionOfHandles/(MAXIMUM_POSITION_OF_HANDLES*radiusXAxis);
    transparencyForAxis = (transparencyForAxis>1.0f)?1.0f:transparencyForAxis;
    transparencyForAxis = (transparencyForAxis<0.0f)?0.0f:transparencyForAxis;
    
    centerOfCircleX += offsetPositionOfHandles;
    
    //put background of handles to black
    glColor4f(0.0f, 0.0f, 0.0f, 1.0f);
    gl::drawSolidRect(Rectf(-maxTimeSpan,maxVoltsSpan,centerOfCircleX+1.6*radiusXAxis,-maxVoltsSpan));

    //draw all handles
    for(int indexOfChannel = 0;indexOfChannel<maxNumberOfChannels;indexOfChannel++)
    {
        //draw tickmark
        if([self channelActive:indexOfChannel])
        {
            glLineWidth(2.0f);
            glColor4f(1.0f, 1.0f, 1.0f, 1.0-transparencyForAxis);
            gl::drawLine(Vec2f(-maxTimeSpan, yOffsets[indexOfChannel]), Vec2f(-maxTimeSpan+20*scaleXY.x, yOffsets[indexOfChannel]));
            
        }

         //draw handle for active channels
        [self setColorWithIndex:indexOfChannel transparency:1.0f];
        if(self.mode == MultichannelGLViewModeView || [self channelActive:indexOfChannel])
        {
            gl::drawSolidEllipse( Vec2f(centerOfCircleX, yOffsets[indexOfChannel]), radiusXAxis, radiusYAxis, 1000 );
            gl::drawSolidTriangle(
                                  Vec2f(centerOfCircleX+0.35*radiusXAxis, yOffsets[indexOfChannel]+radiusYAxis*0.97),
                                  Vec2f(centerOfCircleX+1.6*radiusXAxis, yOffsets[indexOfChannel]),
                                  Vec2f(centerOfCircleX+0.35*radiusXAxis, yOffsets[indexOfChannel]-radiusYAxis*0.97)
                                  );
        }
        
        //draw line for active channel
        
        if([self channelActive:indexOfChannel])
        {
            [self setColorWithIndex:indexOfChannel transparency:transparencyForAxis];
            glLineWidth(2.0f);
            gl::drawLine(Vec2f(centerOfCircleX, yOffsets[indexOfChannel]), Vec2f(0.0f, yOffsets[indexOfChannel]));

        }
        glLineWidth(1.0f);
        
        
        [self setColorWithIndex:indexOfChannel transparency:1.0f];
        //draw holow unselected handle
        if(indexOfChannel!=selectedChannel)
        {
            glColor4f(0.0f, 0.0f, 0.0f, 1.0f);
            gl::drawSolidEllipse( Vec2f(centerOfCircleX, yOffsets[indexOfChannel]), radiusXAxis*0.8, radiusYAxis*0.8, 1000 );
        }
        else
        {
            if(self.mode == MultichannelGLViewModeView && multichannel)
            {
                //Draw X icon for channel removal
                //Draw X icon for channel removal
                xPositionOfRemove = - offsetPositionOfHandles -60*scaleXY.x;
                yPositionOfRemove = yOffsets[indexOfChannel]+100*scaleXY.y;
                gl::drawSolidEllipse( Vec2f(xPositionOfRemove, yPositionOfRemove), radiusXAxis+2*scaleXY.x, radiusYAxis+2*scaleXY.y, 1000 );
                glColor4f(0.0f, 0.0f, 0.0f, 1.0f);
                gl::drawSolidEllipse( Vec2f(xPositionOfRemove, yPositionOfRemove), radiusXAxis+0.0*scaleXY.x, radiusYAxis+0.0*scaleXY.y, 1000 );
                [self setColorWithIndex:indexOfChannel transparency:1.0f];
                glLineWidth(2.0f);
                gl::drawLine(Vec2f(xPositionOfRemove-radiusXAxis*0.7, yPositionOfRemove), Vec2f(xPositionOfRemove+radiusXAxis*0.7, yPositionOfRemove));
                glLineWidth(1.0f);
            }
        }
        
        //draw RT handle on selected channe;
        if(indexOfChannel == selectedChannel)
        {
            if(self.mode == MultichannelGLViewModeView && [[BBAudioManager bbAudioManager] rtSpikeSorting])
            {
                float zoom = maxVoltsSpan/ numVoltsVisible[selectedChannel];
                float xPositionOfThreshold = - offsetPositionOfHandles-radiusXAxis;
                float yPositionOfThreshold = yOffsets[indexOfChannel]+[[BBAudioManager bbAudioManager] rtThreshold]*zoom;
                
                gl::drawSolidEllipse( Vec2f(xPositionOfThreshold, yPositionOfThreshold), radiusXAxis, radiusYAxis, 1000 );
                gl::drawSolidTriangle(
                                      Vec2f(xPositionOfThreshold-0.35*radiusXAxis, yPositionOfThreshold+radiusYAxis*0.97),
                                      Vec2f(xPositionOfThreshold-1.6*radiusXAxis, yPositionOfThreshold),
                                      Vec2f(xPositionOfThreshold-0.35*radiusXAxis, yPositionOfThreshold-radiusYAxis*0.97)
                                      );
                [self setColorWithIndex:indexOfChannel transparency:transparencyForAxis];

                gl::drawLine(Vec2f(-maxTimeSpan, yPositionOfThreshold), Vec2f(0.0f, yPositionOfThreshold));
                
            }
        
        }
        

    }
    gl::enableDepthRead();
}


//
// Draw spikes of all spike trains
//
-(void) drawSpikes
{
  
    //we use timestamp (timeForSincDrawing) that is taken from audio manager "at the same time"
    //when we took data from circular buffer to display waveform. It is important for sinc of waveform and spike marks
    float currentTime = timeForSincDrawing ;
    
    //If we are not playing (we are scrubbing) than take time stamp directly from audio manager

    //float currentTime = [dataSourceDelegate getCurrentTimeForSinc];
    NSMutableArray * allChannels = [dataSourceDelegate getChannels];
    
    
    float realNumberOfSamplesVisible = numSamplesVisible;
    /*if (realNumberOfSamplesVisible > numSamplesMax) {
        realNumberOfSamplesVisible = numSamplesMax;
    }*/
    if (realNumberOfSamplesVisible < numSamplesMin) {
        realNumberOfSamplesVisible = numSamplesMin;
    }
    
    //calc. real size of time span that is displayed
    float virtualVisibleTimeSpan = realNumberOfSamplesVisible * 1.0f/samplingRate;
    
    //calc. real start and end time
    float graphStartTime =currentTime - virtualVisibleTimeSpan;
    float realEndTime = currentTime;
    
    //Graph start time represents smalest time of visible graph
    //this is important since graph is limited to numSamplesMax
    //and we have elastic animation if user zoom out more than numSamplesMax
    //So we need to filter spikes to show only spikes that have graph in background

    if (realNumberOfSamplesVisible > numSamplesMax) {
        graphStartTime = currentTime - numSamplesMax * 1.0f/samplingRate;
    }
    
    if(graphStartTime<0.0f)
    {
        graphStartTime = 0.0f;
    }

    //Draw spikes
    glColor4f(1.0f, 0.0f, 0.0f, 1.0f);
    BOOL weAreInInterval = NO;



    

    BBSpike * tempSpike;
    BBChannel * tempChannel;
    BBSpikeTrain * tempSpikeTrain;
    int i=0;
    float sizeOfPointX = scaleXY.x * 5;
    float sizeOfPointY = scaleXY.y * 5;
    
    for (int channelIndex=0;channelIndex<[allChannels count];channelIndex++)
    {
        tempChannel = [allChannels objectAtIndex:channelIndex];
        //offset of channel
        float zeroOffset = yOffsets[channelIndex];
        //volts zoom
        float zoom = maxVoltsSpan/ numVoltsVisible[channelIndex];
        for(int trainIndex=0;trainIndex<[[tempChannel spikeTrains] count];trainIndex++)
        {
            tempSpikeTrain = [[tempChannel spikeTrains] objectAtIndex:trainIndex];
            

                weAreInInterval = NO;
            
                //[self setColorWithIndex:(trainIndex+(channelIndex+1)) transparency:1.0f];
                [self setGLColor:[BYBGLView getSpikeTrainColorWithIndex:trainIndex transparency:1.0f]];
                i++;
                //go through all spikes
                for (tempSpike in tempSpikeTrain.spikes) {
                    if([tempSpike time]>graphStartTime && [tempSpike time]<realEndTime)
                    {
                        weAreInInterval = YES;//we are in visible interval
                        //reacalculate spikes to virtual GL x axis [-maxTimeSpan, 0]
                        float xValue = ([tempSpike time] -realEndTime)*(maxTimeSpan/virtualVisibleTimeSpan);
                        //recalculate Y axis with zoom and offset
                        float yValue = [tempSpike value] * zoom +zeroOffset;
                        
                        //draw spike mark
                        //gl::drawSolidRect(Rectf(xValue-sizeOfPointX,yValue-sizeOfPointY,xValue+sizeOfPointX,yValue+sizeOfPointY));
                        //draw spike mark
                        gl::drawSolidEllipse( Vec2f(xValue, yValue), sizeOfPointX,sizeOfPointY, 40 );
                    }
                    else if(weAreInInterval)
                    {//if we pass last spike in visible interval
                        break;
                    }
                }
        }
    }
  
}

//
//
// Draw RT spikes on selected channel
-(void) drawRTSpikes
{
    float * spikeIndexes = [[BBAudioManager bbAudioManager] rtSpikeIndexes];
    float * spikeValues = [[BBAudioManager bbAudioManager] rtSpikeValues];
    float zeroOffset = yOffsets[selectedChannel];
    int numberOfSpikes = [[BBAudioManager bbAudioManager] numberOfRTSpikes];
    
    
    float realNumberOfSamplesVisible = numSamplesVisible;
    /*if (realNumberOfSamplesVisible > numSamplesMax) {
     realNumberOfSamplesVisible = numSamplesMax;
     }*/
    if (realNumberOfSamplesVisible < numSamplesMin) {
        realNumberOfSamplesVisible = numSamplesMin;
    }
    //calc. real size of time span that is displayed
    float virtualVisibleTimeSpan = realNumberOfSamplesVisible * 1.0f/samplingRate;
    
    float sizeOfPointX = scaleXY.x * 5;
    float sizeOfPointY = scaleXY.y * 5;
    [self setGLColor:[BYBGLView getSpikeTrainColorWithIndex:selectedChannel transparency:1.0f]];
    float zoom = maxVoltsSpan/ numVoltsVisible[selectedChannel];
    float thrValue = [[BBAudioManager bbAudioManager] rtThreshold];
    
    for(int i=0;i<numberOfSpikes;i++)
    {
        if(spikeValues[i]!=0.0f && spikeValues[i]>thrValue)
        {
            float xValue = spikeIndexes[i] * (-(1.0f/samplingRate)) * (maxTimeSpan/virtualVisibleTimeSpan);
            if(spikeIndexes[i]>numSamplesMax)
            {
                continue;
            }
            //recalculate Y axis with zoom and offset
            float yValue = spikeValues[i] * zoom +zeroOffset;
            
            gl::drawSolidEllipse( Vec2f(xValue, yValue), sizeOfPointX,sizeOfPointY, 40 );
        }
    }
}


//
//Draw X scale
//
- (void)drawScaleText
{
    gl::disableDepthRead();
    gl::setMatricesWindow( Vec2i(self.frame.size.width, self.frame.size.height) );
	gl::enableAlphaBlending();
    
    float xScale = 0.5*numSamplesVisible*(1/samplingRate)*1000;//1000.0*(xMiddle.x - xFarLeft.x);

    /*if([[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale]==2.0)
    {//if it is retina correct scale
        //TODO: This should be tested with calibration voltage source
        xScale *= 2.0f;
        yScale /=2.0f;
    }*/
    
    std::stringstream xStringStream;
    xStringStream.precision(1);
    if (xScale >= 1000) {
        xScale /= 1000.0;
        //xStringStream.precision(1);
        xStringStream << fixed << xScale << " s";
    }
    else {
       // xStringStream.precision(2);
        xStringStream << fixed << xScale << " msec";
    }
    
    //==================================================
    //Debug code for BT sample rate
    /* float br = [[BBBTManager btManager] currentBaudRate];
     if (br >= 1000) {
     br /= 1000.0;
     xStringStream << fixed << br << " KBps";
     }
     else {
     xStringStream << fixed << br << " Bps";
     }*/
    //==================================================
    
    
    //==================================================
    //Debug code for BT buffer size
    if([[BBAudioManager bbAudioManager] btOn])
    {
        //xStringStream.str("");
        //xStringStream << [[BBBTManager btManager] numberOfFramesBuffered] << " Samp.";
        if([dataSourceDelegate respondsToSelector:@selector(updateBTBufferIndicator)])
        {
            [dataSourceDelegate updateBTBufferIndicator];
        }
        
    }
    //==================================================
    
	gl::color( ColorA( 1.0, 1.0f, 1.0f, 1.0f ) );

  
    //draw x-scale text
    // Now that we have the string, calculate the position of the x-scale text
    // (we'll be horizontally centering by hand)
    Vec2f xScaleTextSize = mScaleFont->measureString(xStringStream.str());
    Vec2f xScaleTextPosition = Vec2f(0.,0.);
    xScaleTextPosition.x = (self.frame.size.width - xScaleTextSize.x)/2.0;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        
        xScaleTextPosition.y =0.88*self.frame.size.height + (mScaleFont->getAscent() / 2.0f);
    }
    else
    {
        xScaleTextPosition.y =0.95*self.frame.size.height + (mScaleFont->getAscent() / 2.0f);
    }
    mScaleFont->drawString(xStringStream.str(), xScaleTextPosition);
    

    gl::enableDepthRead();
    
}




//Draw line for time scale
- (void)drawGrid
{
    //draw line for x-axis
    float left, top, right, bottom, near, far;
    mCam.getFrustum(&left, &top, &right, &bottom, &near, &far);
    float height = top - bottom;
    float width = right - left;
    float middleX = (right - left)/2.0f + left;

    float lineLength = 0.5*width;
    float lineY = height*0.1 + bottom;
    Vec2f leftPoint = Vec2f(middleX - lineLength / 2.0f, lineY);
    Vec2f rightPoint = Vec2f(middleX + lineLength / 2.0f, lineY);
    glColor4f(0.8, 0.8, 0.8, 1.0);
    glLineWidth(1.0f);
    gl::drawLine(leftPoint, rightPoint);
   
}

//====================================== TOUCH ==============================================================================
#pragma mark - Touch Navigation - Zoom

//
// Gives size of pinch/zoom
//
- (Vec2f)calculateTouchDistanceChange:(std::vector<ci::app::TouchEvent::Touch>)touches
{
    
    float thisXDistance = touches[0].getX() - touches[1].getX();
    float thisYDistance = touches[0].getY() - touches[1].getY();
    float prevXDistance = touches[0].getPrevX() - touches[1].getPrevX();
    float prevYDistance = touches[0].getPrevY() - touches[1].getPrevY();
    
    float deltaX = thisXDistance / prevXDistance;
    float deltaY = thisYDistance / prevYDistance;
    
    // Turns out you can't get your fingers much closer than 40 pixels.
    // TODO: check this on non-retina
    float minPinchDistance = 40.0f;
    
    // If the touches are closer than the minimum pinch distance in some axis,
    // it's because the fingers are separated in the orthogonal axis, and so movement along
    // the much-too-close axis should be ignored.
    // e.g. if you're pinching vertically, you should probably ignore horizontal movement.
    if (abs(thisXDistance) <= minPinchDistance)
        deltaX = 1.0f;
    
    if (abs(thisYDistance) <= minPinchDistance)
        deltaY = 1.0f;
    
    // This is a safety net.
    // If for some reason we don't get a pinch right, and we divide by zero or something stupid,
    // make sure we don't pass a nan out. That destroys everything.
    if ( isnan(deltaX) || deltaX<0.0f)
        deltaX = 1.0f;
    
    if ( isnan(deltaY)  || deltaY<0.0f)
        deltaY = 1.0f;
    
    return Vec2f(deltaX, deltaY);
}

//
// React on one and two finger gestures
//
- (void)updateActiveTouches
{
    [super updateActiveTouches];
    //NSLog(@"Num volts visible: %f", numVoltsVisible[0]);
    
    std::vector<ci::app::TouchEvent::Touch> touches = [self getActiveTouches];
    
    // Pinching to zoom the display
    if (touches.size() == 2)
    {
        Vec2f touchDistanceDelta = [self calculateTouchDistanceChange:touches];
        float oldNumSamplesVisible = numSamplesVisible;
        float oldNumVoltsVisible = numVoltsVisible[selectedChannel];
        
        float deltax = fabs(touchDistanceDelta.x-1.0f);
        float deltay = fabs(touchDistanceDelta.y-1.0f);
        // NSLog(@"Touch X: %f", deltax/deltay);
        if((deltax/deltay)<0.4 || touchDistanceDelta.y != 1.0f)
        {
            touchDistanceDelta.x = 1.0f;
        }
        if((deltay/deltax)<0.4)
        {
            touchDistanceDelta.y = 1.0f;
        }
        
        numSamplesVisible /= (touchDistanceDelta.x - 1) + 1;
        numVoltsVisible[selectedChannel] /= (touchDistanceDelta.y - 1) + 1;
       
        // Make sure that we don't go out of bounds
        if (numSamplesVisible < numSamplesMin )
        {
            touchDistanceDelta.x = 1.0f;
            numSamplesVisible = oldNumSamplesVisible;
        }
        if (numVoltsVisible[selectedChannel] < 0.001)
        {
            touchDistanceDelta.y = 1.0f;
            numVoltsVisible[selectedChannel] = oldNumVoltsVisible;
        }
        
        if(numVoltsVisible[selectedChannel]>numVoltsMax)
        {
            touchDistanceDelta.y = 1.0f;
            numVoltsVisible[selectedChannel] = oldNumVoltsVisible;
        }
        
        // If we are thresholding,
        // we will not allow the springy x-axis effect to occur
        // (why? we always want the x-axis to be centered on the threshold value)
        if (mode == MultichannelGLViewModeThresholding) {
            // slightly tigher bounds on the thresholding view (don't need to see whole second and a half in this view)
            // TODO: this is a hack to get thresholding to have a separate number of seconds visible. I weep for how awful this is. I am so sorry.
            float thisNumSamplesMax= MAX_THRESHOLD_VISIBLE_TIME*samplingRate;
            if(numSamplesVisible >= thisNumSamplesMax)
            {
                numSamplesVisible = oldNumSamplesVisible;
                touchDistanceDelta.x = 1.0f;
            }
        }
        
        
       
        //Change x axis values so that only numSamplesVisible samples are visible for selected channel
        float zero = 0.0f;
        float zoom = touchDistanceDelta.x;
        int realIndexOfChannel = 0;
        for(int channelIndex = 0;channelIndex<maxNumberOfChannels;channelIndex++)
        {
            if([self channelActive:channelIndex])
            {
                
                vDSP_vsmsa ((float *)&(displayVectors[realIndexOfChannel].getPoints()[0]),
                         2,
                         &zoom,
                         &zero,
                         (float *)&(displayVectors[realIndexOfChannel].getPoints()[0]),
                         2,
                         numSamplesMax
                         );
                realIndexOfChannel++;
            }
        }
       
    }
    
    // Touching to change the threshold value, if we're thresholding
    //Selecting time interval and thresholding are mutualy exclusive
    else if (touches.size() == 1)
    {
        //last time we tap screen with one finger. We use this to hide hanles
        lastUserInteraction = [[NSDate date] timeIntervalSince1970];

        BOOL weAreHoldingHandle = NO;
        
        Vec2f touchPos = touches[0].getPos();
        // Convert into GL coordinate
        Vec2f glWorldTouchPos = [self screenToWorld:touchPos];

        int grabbedHandleIndex;
        
        //if user grabbed the handle of channel
        if((multichannel || self.mode == MultichannelGLViewModeView) && (grabbedHandleIndex = [self checkIntersectionWithHandles:glWorldTouchPos])!=-1)
        {
            
            weAreHoldingHandle = YES;
            //move channel
            yOffsets[grabbedHandleIndex] = glWorldTouchPos.y;
            
            //if we drag handle outside the screen return it back
            float upperBoundary =(maxVoltsSpan*0.5 - HANDLE_RADIUS*scaleXY.y);
            if(yOffsets[grabbedHandleIndex]>upperBoundary)
            {
                yOffsets[grabbedHandleIndex] = upperBoundary;
            }
            
            float lowerBoundary = -upperBoundary;
            if(yOffsets[grabbedHandleIndex]<lowerBoundary)
            {
                yOffsets[grabbedHandleIndex] = lowerBoundary;
            }
            //select channel
            if(selectedChannel!=grabbedHandleIndex)
            {
                
                
                if([self channelActive:grabbedHandleIndex])
                {
                    selectedChannel = grabbedHandleIndex;
                    if ([dataSourceDelegate respondsToSelector:@selector(selectChannel:)]) {
                        
                        //Calculate compressed selected channel for AudioManager
                        
                        int compressedSelectedChannel = 0;
                        for(int i =0;i<maxNumberOfChannels;i++)
                        {
                            if(i==grabbedHandleIndex)
                            {
                                break;
                            }
                            if([self channelActive:i])
                            {
                                compressedSelectedChannel++;
                            }
                        }
                        //Select channel on audio manager
                        NSLog(@"%d - selected handle: %d", compressedSelectedChannel, grabbedHandleIndex);
                        [dataSourceDelegate selectChannel:compressedSelectedChannel];
                    }
                
                }
                else
                {
                    if([dataSourceDelegate respondsToSelector:@selector(addChannel:)])
                    {
                        [dataSourceDelegate addChannel:grabbedHandleIndex];
                    }
                }
            }
        
        }
        
        //RT spike sorting line
        if(self.mode == MultichannelGLViewModeView && [[BBAudioManager bbAudioManager] rtSpikeSorting])
        {
            float zoom = maxVoltsSpan/ numVoltsVisible[selectedChannel];
            Vec2f screenThresholdPos1 = [self worldToScreen:Vec2f(0.0f, [[BBAudioManager bbAudioManager] rtThreshold]*zoom + yOffsets[selectedChannel])];
            
            float distance1 = (touchPos.y - screenThresholdPos1.y)*(touchPos.y - screenThresholdPos1.y)+(touchPos.x - screenThresholdPos1.x)*(touchPos.x - screenThresholdPos1.x);
            
            if (distance1 < 8500) // set via experimentation
            {
                [[BBAudioManager bbAudioManager] setRtThreshold:(glWorldTouchPos.y-yOffsets[selectedChannel])/zoom];
                return;
            }
        }
        
        //Remove channel X button
        if([self checkIntesectionWithRemoveButton:glWorldTouchPos])
        {
            if([dataSourceDelegate respondsToSelector:@selector(removeChannel:)])
            {
                [dataSourceDelegate removeChannel:selectedChannel];
            }
        }
        
        //if we are not moving channels check if need to make interval selection or threshold
        if(!weAreHoldingHandle)
        {
            BOOL changingThreshold;
            changingThreshold = false;
            
            //thresholding
            if (self.mode == MultichannelGLViewModeThresholding && ![dataSourceDelegate selecting]) {

                float zoom = maxVoltsSpan/ numVoltsVisible[selectedChannel];
                float currentThreshold = [dataSourceDelegate threshold]*zoom;

                float intersectionDistanceX = 16000*scaleXY.x*scaleXY.x;
                float intersectionDistanceY = 18000*scaleXY.y*scaleXY.y;
                
                //check first if user grabbed selected channel
                if((glWorldTouchPos.y - (yOffsets[selectedChannel]+currentThreshold))*(glWorldTouchPos.y - (yOffsets[selectedChannel]+currentThreshold)) < intersectionDistanceY && (glWorldTouchPos.x * glWorldTouchPos.x) <intersectionDistanceX)
                {
                    changingThreshold = true;
                    [dataSourceDelegate setThreshold:(glWorldTouchPos.y-yOffsets[selectedChannel])/zoom];
                }
            }
            
            if ([dataSourceDelegate respondsToSelector:@selector(shouldEnableSelection)] && !changingThreshold) {
                if([dataSourceDelegate shouldEnableSelection])
                {
                    
                    float virtualVisibleTimeSpan = numSamplesVisible * 1.0f/samplingRate;
                    
                    //time from right end of the screen to touch position (positive value)
                    timePos = (glWorldTouchPos.x/(-maxTimeSpan))*virtualVisibleTimeSpan;
                    
                    //NSLog(@"%f",timePos);
                    //if selection is enabled
                    if(selectionEnabledAfterSecond)
                    {
                        touchTimer = nil;
                    
                        
                        [dataSourceDelegate updateSelection:timePos timeSpan:virtualVisibleTimeSpan];
                
                    }
                    else
                    {
                    // if selection is not enabled

                        if (touchTimer==nil)//if timer is not running start it
                        {
                            touchTimer = [NSTimer scheduledTimerWithTimeInterval:0.6 target:self selector:@selector(touchHasBeenHeld:) userInfo:nil repeats:NO];
                            //remember starting touch position
                            startX = touchPos.x;
                            startY = touchPos.y;
                        }
                        else
                        {
                        //if timer is already running check if we are moving finger
                            if(abs(startY-touchPos.y)>2 || abs(startX-touchPos.x)>2)
                            {
                                //if we are moving finger reset timer
                                [touchTimer invalidate];
                                touchTimer = nil;
                                touchTimer = [NSTimer scheduledTimerWithTimeInterval:0.6 target:self selector:@selector(touchHasBeenHeld:) userInfo:nil repeats:NO];
                            }
                            
                        }
                        
                    }
                    
                }
            }
            
            
            //one finger scrubbing
            if(self.mode == MultichannelGLViewModePlayback && !selectionEnabledAfterSecond)
            {
                if(![[BBAudioManager bbAudioManager] playing])
                {
                    //playerWasPlayingWhenStoped = [BBAudioManager]
                    float windowWidth = self.frame.size.width;
                    if([[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale]==2.0)
                    {
                        windowWidth += windowWidth;
                    }
                    float diffPix = touches[0].getPos().x - touches[0].getPrevPos().x;
                    float timeDiff = -diffPix*(numSamplesVisible/windowWidth)*(1/[[BBAudioManager bbAudioManager] sourceSamplingRate]);
                    [[BBAudioManager bbAudioManager] setSeeking:YES];
                    [[BBAudioManager bbAudioManager] setCurrentFileTime:[[BBAudioManager bbAudioManager] currentFileTime] + timeDiff ];
                }
                
            }
            
            
        
        }
        
    }
}

-(void) touchHasBeenHeld:(id) e
{
    if(touchTimer!=nil)
    {
        selectionEnabledAfterSecond = true;
        [dataSourceDelegate updateSelection:timePos*0.9999 timeSpan:(numSamplesVisible * 1.0f/samplingRate)];
        [dataSourceDelegate updateSelection:timePos timeSpan:(numSamplesVisible * 1.0f/samplingRate)];
        [touchTimer invalidate];
        touchTimer = nil;
    }

}

-(BOOL) checkIntesectionWithRemoveButton:(Vec2f) touchPos
{
    float intersectionDistanceX = 800*scaleXY.x*scaleXY.x;
    float intersectionDistanceY = 800*scaleXY.y*scaleXY.y;
    if(!multichannel)
    {
        return NO;
    }
    //check first if user grabbed selected channel
    if((touchPos.y - yPositionOfRemove)*(touchPos.y - yPositionOfRemove) < intersectionDistanceY && (touchPos.x - xPositionOfRemove)*(touchPos.x - xPositionOfRemove) <intersectionDistanceX)
    {
        return YES;
    }
    return NO;
}


//
// Check if touch is in vicinity of channel's handle
//
-(int) checkIntersectionWithHandles:(Vec2f) touchPos
{
    float intersectionDistanceX = 8000*scaleXY.x*scaleXY.x;
    float intersectionDistanceY = 8000*scaleXY.y*scaleXY.y;
    
    //check first if user grabbed selected channel
    if((touchPos.y - yOffsets[selectedChannel])*(touchPos.y - yOffsets[selectedChannel]) < intersectionDistanceY && (touchPos.x - (-maxTimeSpan))*(touchPos.x - (-maxTimeSpan)) <intersectionDistanceX)
    {
        return selectedChannel;
    }
    
    //check for other channels
    for(int channelIndex=0;channelIndex<maxNumberOfChannels;channelIndex++)
    {
        if(channelIndex == selectedChannel)
        {
            continue;
        }
        
        if ((touchPos.y - yOffsets[channelIndex])*(touchPos.y - yOffsets[channelIndex]) < intersectionDistanceY && (touchPos.x - (-maxTimeSpan))*(touchPos.x - (-maxTimeSpan)) <intersectionDistanceX) // set via experimentation
        {
            return channelIndex;
        }
    }
    return -1;
}



- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event
{
    //if touch begins remove old time interval selection
    if ([dataSourceDelegate respondsToSelector:@selector(endSelection)])
    {
        [dataSourceDelegate endSelection];
        selectionEnabledAfterSecond = false;
        [touchTimer invalidate];
        touchTimer = nil;
    }
    
    
    
    [super touchesBegan:touches withEvent:event];
    
}

- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event
{
    //if user just tapped on screen start and end point will
    //be the same so we will remove time interval selection
    if ([dataSourceDelegate respondsToSelector:@selector(endSelection)])
    {
        if([dataSourceDelegate selectionStartTime] == [dataSourceDelegate selectionEndTime])
        {
            [dataSourceDelegate endSelection];
        }
    }
   
    [touchTimer invalidate];
    touchTimer = nil;
    
    [super touchesEnded:touches withEvent:event];
}




/*
 
 //
 // Called when user stop dragging scruber
 //
 - (void)sliderTouchUpInside:(NSNotification *)notification {
 if(!audioPaused)
 {
 [bbAudioManager setSeeking:NO];
 [bbAudioManager resumePlaying];
 }
 }
 
 //
 // Called when user start dragging scruber
 //
 - (void)sliderTouchDown:(NSNotification *)notification {
 [bbAudioManager setSeeking:YES];
 [bbAudioManager pausePlaying];
 audioPaused = YES;
 }
 
 //Seek to new place in file
 - (IBAction)backBtnClick:(id)sender {
 [self.navigationController popViewControllerAnimated:YES];
 }
 
 - (IBAction)sliderValueChanged:(id)sender {
 
 bbAudioManager.currentFileTime = (float)self.timeSlider.value;
 }
 */















#pragma mark - Utility


//
// Calculate position in GL world units based on point in screen pixels
//
- (Vec2f)screenToWorld:(Vec2f)point
{
    
    float windowHeight = self.frame.size.height;
    float windowWidth = self.frame.size.width;
    if([[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale]==2.0)
    {
        //if it is retina
        windowHeight += windowHeight;
        windowWidth += windowWidth;
    }
    
    float worldLeft, worldTop, worldRight, worldBottom, worldNear, worldFar;
    mCam.getFrustum(&worldLeft, &worldTop, &worldRight, &worldBottom, &worldNear, &worldFar);
    float worldHeight = worldTop - worldBottom;
    float worldWidth = worldRight - worldLeft;
    
    // Normalize
    Vec2f outPoint = Vec2f(point);
    outPoint.x = (outPoint.x / windowWidth);
    outPoint.y = (windowHeight - outPoint.y) / windowHeight; // origin in device coordinates starts in upper left, but in GL, lower left.
    
    // Convert to world coordinates
    outPoint.x = outPoint.x * worldWidth + worldLeft;
    outPoint.y = outPoint.y * worldHeight + worldBottom;
    
    return outPoint;
}


//
// Calculate position in screen pixels based on point in GL world units
//
- (Vec2f)worldToScreen:(Vec2f)point
{
    
    float windowHeight = self.frame.size.height;
    float windowWidth = self.frame.size.width;
    
    if([[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale]==2.0)
    {
        //if it is retina
        windowHeight += windowHeight;
        windowWidth += windowWidth;
    }
    
    float worldLeft, worldTop, worldRight, worldBottom, worldNear, worldFar;
    mCam.getFrustum(&worldLeft, &worldTop, &worldRight, &worldBottom, &worldNear, &worldFar);
    float worldHeight = worldTop - worldBottom;
    float worldWidth = worldRight - worldLeft;
    
    
    // Normalize
    Vec2f outPoint = Vec2f(point);
    outPoint.x = (outPoint.x - worldLeft) / worldWidth;
    outPoint.y = (outPoint.y - worldBottom) / worldHeight;
    
    // Convert to screen coordinates
    outPoint.x = outPoint.x * windowWidth;
    outPoint.y = windowHeight - outPoint.y * windowHeight;
    
    return outPoint;
}


//Change color of spike marks according to index
-(void) setColorWithIndex:(int) iindex transparency:(float) transp
{
    iindex = iindex%5;
    switch (iindex) {
        case 0:
            glColor4f(0.9686274509803922f, 0.4980392156862745f, 0.011764705882352941f, transp);
            break;
        case 1:
            glColor4f(1.0f, 0.011764705882352941f, 0.011764705882352941f, transp);
            break;
        case 2:
            glColor4f( 0.9882352941176471f, 0.9372549019607843f, 0.011764705882352941f, transp);
            break;
        case 3:
            glColor4f(0.0f, 0.0f, 1.0f, transp);
            break;
        case 4:
            glColor4f(1.0f, 0.0f, 1.0f, transp);
            break;
    }
    
}




@end
