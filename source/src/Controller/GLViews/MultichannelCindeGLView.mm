//
//  MultichannelCindeGLView.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 5/28/14.
//  Copyright (c) 2014 Backyard Brains. All rights reserved.
//

#import "MultichannelCindeGLView.h"
#import <Accelerate/Accelerate.h>
#import "BBSpike.h"
#import "BBEvent.h"
#import "BBSpikeTrain.h"
#import "BBChannel.h"
#import "BBAudioManager.h"
#define HANDLE_RADIUS 10

#define MAX_THRESHOLD_VISIBLE_TIME 2.4
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
    
    
    NSTimer * autorangeTimer;
    BOOL autorangeActive;
}

@end


@implementation MultichannelCindeGLView

@synthesize mode;//operational mode - enum MultichannelGLViewMode
@synthesize rtConfigurationActive;
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

    mFont = Font("Helvetica", 18);//36/retinaScaling);
    mScaleFont = gl::TextureFont::create( mFont );
    
    currentTimeFont = Font("Helvetica", 13);//26/retinaScaling);
    currentTimeTextureFont = gl::TextureFont::create( currentTimeFont );
    
    heartBeatFont = Font("Helvetica", 24);//36/retinaScaling);
    heartBeatTextureFont = gl::TextureFont::create( heartBeatFont );
    
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
    if(newNumberOfChannels!=maxNumberOfChannels)
    {
        numVoltsVisible= nil;
    }
    maxNumberOfChannels = newNumberOfChannels;
    
    
    firstDrawAfterChannelChange = YES;
    NSLog(@"CinderGLVIew Setup num of channel");
    [self stopAnimation];

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
        
        //delete[] numVoltsVisible;
        //delete[] yOffsets;
        delete[] tempDataBuffer;
    }
    displayVectors =  new PolyLine2f[newNumberOfChannels];
    [self checkIfWeHaveVoltageScale];
    [self setCurrentVoltageScaleToDefault];
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
        //if(yOffsets[channelIndex]==0.0f)
        //{
            yOffsets[channelIndex] = -usableYAxisSpan*0.4 + (channelIndex+1)*(usableYAxisSpan/((float)maxNumberOfChannels))- 0.5*(usableYAxisSpan/((float)maxNumberOfChannels));
        //}
    }
    if(maxNumberOfChannels==1)
    {
        yOffsets[0] = 0.0f;
    }
    
    dataSourceDelegate = newDataSource;

    selectedChannel = 0;
            
    if ([dataSourceDelegate respondsToSelector:@selector(selectChannel:)]) {
        [dataSourceDelegate selectChannel:0];
    }
    
    NSLog(@"End setup number of channels");
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

-(void) setCurrentTimeScale:(float) timeScaleToSet
{
    float tempNumberOfSampleVisible =(1.0*samplingRate)*timeScaleToSet;
    if(tempNumberOfSampleVisible>MAX_THRESHOLD_VISIBLE_TIME*samplingRate)
    {
        tempNumberOfSampleVisible = MAX_THRESHOLD_VISIBLE_TIME*samplingRate;
    }
    if(tempNumberOfSampleVisible<numSamplesMin)
    {
        tempNumberOfSampleVisible =numSamplesMin;
    }
    numSamplesVisible = tempNumberOfSampleVisible;
    NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (mode==MultichannelGLViewModeThresholding) {
        [defaults setValue:[NSNumber numberWithFloat:numSamplesVisible] forKey:@"numSamplesVisibleThreshold"];
    }
    else {
        [defaults setValue:[NSNumber numberWithFloat:numSamplesVisible] forKey:@"numSamplesVisible"];
    }
}

-(void) setCurrentVoltageScaleToDefault
{
    if(numVoltsVisible!=nil)
    {
        delete[] numVoltsVisible;
    }
    numVoltsVisible = new float[[[BBAudioManager bbAudioManager] numberOfActiveChannels]]; //current zoom for every channel y axis
    for(int i=0;i<[[BBAudioManager bbAudioManager] numberOfActiveChannels];i++)
    {
        float tempVolts =  [[BBAudioManager bbAudioManager] getVoltageScaleForChannelIndex:i];
        if(tempVolts < 0.00001)
        {
            tempVolts = 0.00002;
        }
        if(tempVolts>numVoltsMax)
        {
            tempVolts = numVoltsMax;
        }
        numVoltsVisible[i] = tempVolts;
    }
}
- (void)loadSettings:(BOOL)useThresholdSettings
{
    
    NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Initialize parameters
    if (useThresholdSettings) {
        NSLog(@"Setting threshold defaults");
        numSamplesMax = [[defaults valueForKey:@"numSamplesMaxThresholdNew"] floatValue];
        numSamplesMin = [[defaults valueForKey:@"numSamplesMin"] floatValue];
        numSamplesVisible = [[defaults valueForKey:@"numSamplesVisibleThreshold"] floatValue];
        if(numSamplesVisible>MAX_THRESHOLD_VISIBLE_TIME*samplingRate)
        {
            numSamplesVisible = MAX_THRESHOLD_VISIBLE_TIME*samplingRate;
        }
        numVoltsMin = [[defaults valueForKey:@"numVoltsMinThreshold"] floatValue];
        numVoltsMax = [[defaults valueForKey:@"numVoltsMaxThresholdUpdate1"] floatValue];
       
      /*  for(int i=0;i<maxNumberOfChannels;i++)
        {
            //numVoltsVisible[i] = [[defaults valueForKey:@"numVoltsVisibleThreshold"] floatValue];
            numVoltsVisible[i] = [[defaults valueForKey:@"numVoltsVisible"] floatValue];
            
            //override settings if it is not app startup. Use from BBAudioManager
            //made so that threshold and real time screen can share vertical scale
            if([[BBAudioManager bbAudioManager] maxVoltageVisible]!=MAX_VOLTAGE_NOT_SET)
            {
                numVoltsVisible[i] = [[BBAudioManager bbAudioManager] maxVoltageVisible];
            }
            NSLog(@"Max volts visible: %f", numVoltsVisible[i]);
            if(numVoltsVisible[i] < 0.00001)
            {
                numVoltsVisible[i] = 0.00002;
            }
            if(numVoltsVisible[i]>numVoltsMax)
            {
                numVoltsVisible[i] = numVoltsMax;
            }
        }*/
    }
    else {
        NSLog(@"Setting normal defaults\n");
        numSamplesMax = [[defaults valueForKey:@"numSamplesMaxNew"] floatValue];
        numSamplesMin = [[defaults valueForKey:@"numSamplesMin"] floatValue];
        numSamplesVisible = [[defaults valueForKey:@"numSamplesVisible"] floatValue];
        numVoltsMin = [[defaults valueForKey:@"numVoltsMin"] floatValue];
        numVoltsMax = [[defaults valueForKey:@"numVoltsMaxUpdate1"] floatValue];
        
       /* for(int i=0;i<maxNumberOfChannels;i++)
        {
            numVoltsVisible[i] = [[defaults valueForKey:@"numVoltsVisible"] floatValue];
            //override settings if it is not app startup. Use from BBAudioManager
            //made so that threshold and real time screen can share vertical scale
            if([[BBAudioManager bbAudioManager] maxVoltageVisible]!=MAX_VOLTAGE_NOT_SET)
            {
                numVoltsVisible[i] = [[BBAudioManager bbAudioManager] maxVoltageVisible];
            }
             NSLog(@"Max volts visible: %f", numVoltsVisible[i]);
            if(numVoltsVisible[i]>numVoltsMax)
            {
                numVoltsVisible[i] = numVoltsMax;
            }
            if(numVoltsVisible[i] < 0.00001)
            {
                numVoltsVisible[i] = 0.00002;
            }
        }*/
        
    }
    
    //[self autorangeSelectedChannel];
    
}


-(void) autorangeSelectedChannel
{
    numVoltsVisible[selectedChannel] = [[BBAudioManager bbAudioManager] currMax]*2.6;
    if (self.mode == MultichannelGLViewModeThresholding)
    {
        float zoom = maxVoltsSpan/ numVoltsVisible[selectedChannel];
        [dataSourceDelegate setThreshold:(maxVoltsSpan*0.13)/zoom];
    }
    
}

- (void)saveSettings:(BOOL)useThresholdSettings
{
    NSLog(@"MultichannelGL view saveSettings\n");
    NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Save parameters
    // Initialize parameters
    if (useThresholdSettings) {
        [defaults setValue:[NSNumber numberWithFloat:numSamplesMax] forKey:@"numSamplesMaxThresholdNew"];
        [defaults setValue:[NSNumber numberWithFloat:numSamplesMin] forKey:@"numSamplesMin"];
        [defaults setValue:[NSNumber numberWithFloat:numSamplesVisible] forKey:@"numSamplesVisibleThreshold"];
        [defaults setValue:[NSNumber numberWithFloat:numVoltsMin] forKey:@"numVoltsMinThreshold"];
        
        [defaults setValue:[NSNumber numberWithFloat:numVoltsMax] forKey:@"numVoltsMaxThresholdUpdate1"];
        if(numVoltsVisible[0]>numVoltsMax)
        {
            numVoltsVisible[0] = numVoltsMax;
        }
        //[defaults setValue:[NSNumber numberWithFloat:numVoltsVisible[0]] forKey:@"numVoltsVisibleThreshold"];
        [defaults setValue:[NSNumber numberWithFloat:numVoltsVisible[0]] forKey:@"numVoltsVisible"];
    }
    else {
        [defaults setValue:[NSNumber numberWithFloat:numSamplesMax] forKey:@"numSamplesMaxExt"];
        [defaults setValue:[NSNumber numberWithFloat:numSamplesMax] forKey:@"numSamplesMaxNew"];
        [defaults setValue:[NSNumber numberWithFloat:numSamplesVisible] forKey:@"numSamplesVisible"];
        [defaults setValue:[NSNumber numberWithFloat:numVoltsMin] forKey:@"numVoltsMin"];
        [defaults setValue:[NSNumber numberWithFloat:numVoltsMax] forKey:@"numVoltsMaxUpdate1"];
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
   // NSLog(@"fillDisplayVector");
    
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
                
                for(int channelIndex = 0; channelIndex<maxNumberOfChannels; channelIndex++)
                {
                    vDSP_vsmsa ((float *)&(displayVectors[channelIndex].getPoints()[0]), 2,
                        &zoom,
                        &zero,
                        (float *)&(displayVectors[channelIndex].getPoints()[0]),
                        2,
                        numSamplesMax
                        );
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

                for(int channelIndex = 0; channelIndex<numberOfChannels; channelIndex++)
                {
                    vDSP_vsmsa ((float *)&(displayVectors[channelIndex].getPoints()[0]), 2,
                            &zoom,
                            &zero,
                            (float *)&(displayVectors[channelIndex].getPoints()[0]),
                            2,
                            numSamplesMax
                            );
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

    for(int channelIndex = 0; channelIndex<maxNumberOfChannels; channelIndex++)
    {
        if (!(mode == MultichannelGLViewModeThresholding))
        {
            numPoints = numSamplesMax;
            offset = 0;
        }
    
        timeForSincDrawing =  [dataSourceDelegate fetchDataToDisplay:tempDataBuffer numFrames:numPoints whichChannel:channelIndex];
      //  NSLog(@"After - Fetch Data to display");
        float zero = yOffsets[channelIndex];
        float zoom = maxVoltsSpan/ numVoltsVisible[channelIndex];
        //NSLog(@"%d:%f", channelIndex, zoom);
        //float zoom = 1.0f;
        vDSP_vsmsa (tempDataBuffer,
                    1,
                    &zoom,
                    &zero,
                    (float *)&(displayVectors[channelIndex].getPoints()[offset])+1,
                    2,
                    numPoints
                    );
    }
}

-(void) checkIfWeHaveVoltageScale
{
    //voltage patch
    if(numVoltsVisible==nil)
    {
        numVoltsVisible = new float[maxNumberOfChannels]; //current zoom for every channel y axis
        [self setCurrentVoltageScaleToDefault];
    }
    else
    {
        if(numVoltsVisible[0]==0)
        {
            [self setCurrentVoltageScaleToDefault];
        }
    }
}

- (void)draw {
    
    if(dataSourceDelegate)
    {
        
        [self checkIfWeHaveVoltageScale];
        if(firstDrawAfterChannelChange || viewRotated)
        {
            
            if(viewRotated)
            {
                frameCount = 0;
                viewRotated = false;
                firstDrawAfterChannelChange = YES;
            }
            frameCount++;
            //this is fix for bug. Draw text starts to paint background of text
            //to the same color as text if we don't make new instance here
            //TODO: find a reason for this
           // mScaleFont = nil;
            if(frameCount>4 && !autorangeActive)
            {
                firstDrawAfterChannelChange = NO;
            }
            currentTimeTextureFont = gl::TextureFont::create( currentTimeFont );
            heartBeatTextureFont = gl::TextureFont::create( heartBeatFont );
            mScaleFont = gl::TextureFont::create( mFont );
        }
        
        
        
        currentUserInteractionTime = [[NSDate date] timeIntervalSince1970];
        handlesShouldBeVisible = (currentUserInteractionTime-lastUserInteraction)<HIDE_HANDLES_AFTER_SECONDS;
        
        if([dataSourceDelegate respondsToSelector:@selector(setVisibilityForConfigButton:)])
        {
            [dataSourceDelegate setVisibilityForConfigButton:[[BBAudioManager bbAudioManager] amDemodulationIsON] || [[BBAudioManager bbAudioManager] externalAccessoryIsActive]];
        }

        // this pair of lines is the standard way to clear the screen in OpenGL
        gl::clear( Color( 0.0f, 0.0f, 0.0f ), true );//stanislav commented
        glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );//stanislav commented
        
        
        
        // Look at it right
        mCam.setOrtho(-maxTimeSpan, -0.0f, -maxVoltsSpan/2.0f, maxVoltsSpan/2.0f, 1, 100);
        gl::setMatrices( mCam );
        
        scaleXY = [self screenToWorld:Vec2f(1.0f,1.0f)];
        Vec2f scaleXYZero = [self screenToWorld:Vec2f(0.0f,0.0f)];
        scaleXY.x = fabsf(scaleXY.x - scaleXYZero.x);
        scaleXY.y = fabsf(scaleXY.y - scaleXYZero.y);

        if(autorangeActive)
        {
           // [self autorangeSelectedChannel];
        }
        
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

        //draw signal
        for(int channelIndex=0;channelIndex<maxNumberOfChannels;channelIndex++)
        {
            int colorIndex = [[BBAudioManager bbAudioManager] getColorIndexForActiveChannelIndex:channelIndex];
            [self setColorWithIndex:colorIndex transparency:1.0f];
            gl::draw(displayVectors[channelIndex]);
        }

        //Draw spikes
        glLineWidth(1.0f);
        if(self.mode == MultichannelGLViewModePlayback)
        {
            [self drawSpikes];
        }
        
        //Draw events
        glLineWidth(1.0f);
        if([dataSourceDelegate respondsToSelector:@selector(getEvents)])
        {
            [self drawEvents];
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
             [dataSourceDelegate changeHeartActive:[[BBAudioManager bbAudioManager] heartBeatPresent]];
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
        
        [self drawCurrentTime];
        
        //updates Y axis scale on Audio Manager so that we can transfere
        //it on another screen when user changes the screen
        [[BBAudioManager bbAudioManager] setMaxVoltageVisible:numVoltsVisible[0]];
        
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

        float centerOfCircleX = -(float)retinaScaling*HANDLE_RADIUS*scaleXY.x;
        
        float radiusXAxis = retinaScaling* HANDLE_RADIUS*scaleXY.x;
        float radiusYAxis = retinaScaling* HANDLE_RADIUS*scaleXY.y;
        
        
        if(![[BBAudioManager bbAudioManager] isThresholdTriggered])
        {
            //draw small mark so that user knows where is zero
            glColor4f(0.9, 0.9, 0.9, 1.0);
             gl::drawLine(Vec2f(-maxTimeSpan, 0), Vec2f(-maxTimeSpan+2*HANDLE_RADIUS*scaleXY.x, 0));
            glColor4f(1.0, 0.0, 0.0, 1.0);
        }
        
        
        
        //If threshold is out of screen - up
        if([dataSourceDelegate threshold]>(numVoltsVisible[selectedChannel]*0.4999))
        {
            float positionOfHandleCenterY = 0.5*numVoltsVisible[selectedChannel]*zoom - 1.6*radiusYAxis;
            gl::drawSolidEllipse( Vec2f(centerOfCircleX, positionOfHandleCenterY), radiusXAxis, radiusYAxis, 100 );
            gl::drawSolidTriangle(
                                  Vec2f(centerOfCircleX+radiusXAxis*0.97, positionOfHandleCenterY+0.35*radiusYAxis),
                                  Vec2f(centerOfCircleX, positionOfHandleCenterY+1.6*radiusYAxis),
                                  Vec2f(centerOfCircleX-radiusXAxis*0.97, positionOfHandleCenterY+0.35*radiusYAxis)
                                  );
        
        }//if threshold is out of screen - down
        else if([dataSourceDelegate threshold]<-(numVoltsVisible[selectedChannel]*0.4999))
        {
            float positionOfHandleCenterY = -0.5*numVoltsVisible[selectedChannel]*zoom + 1.6*radiusYAxis;
            gl::drawSolidEllipse( Vec2f(centerOfCircleX, positionOfHandleCenterY), radiusXAxis, radiusYAxis, 100 );
            gl::drawSolidTriangle(
                                  Vec2f(centerOfCircleX+radiusXAxis*0.97, positionOfHandleCenterY-0.35*radiusYAxis),
                                  Vec2f(centerOfCircleX, positionOfHandleCenterY-1.6*radiusYAxis),
                                  Vec2f(centerOfCircleX-radiusXAxis*0.97, positionOfHandleCenterY-0.35*radiusYAxis)
                                  );

        
        }//if threshold is in the screen draw normal line with handle
        else
        {
            //draw handle
            gl::drawSolidEllipse( Vec2f(centerOfCircleX, threshval), radiusXAxis, radiusYAxis, 100 );
            gl::drawSolidTriangle(
                                  Vec2f(centerOfCircleX-0.35*radiusXAxis, threshval+radiusYAxis*0.97),
                                  Vec2f(centerOfCircleX-1.6*radiusXAxis, threshval),
                                  Vec2f(centerOfCircleX-0.35*radiusXAxis, threshval-radiusYAxis*0.97)
                                  );
            
            //draw dashed line
            glLineWidth(2.0f);
            float linePart = radiusXAxis*0.7;
            for(float pos=-maxTimeSpan;pos<-linePart; pos+=linePart+linePart)
            {
                gl::drawLine(Vec2f(pos, threshval), Vec2f(pos+linePart, threshval));
            }
        }
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

    xScaleTextPosition.y =self.frame.size.height-23 + (mScaleFont->getAscent() / 2.0f);
    
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
    
    //self.frame.size.width
    float xPositionOfBackground = self.frame.size.width -widthOfBackground-paddingOfBackground;
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
        hasSomeSpikes = NO;
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

    float radiusXAxis = retinaScaling * HANDLE_RADIUS*scaleXY.x;
    float radiusYAxis = retinaScaling * HANDLE_RADIUS*scaleXY.y;
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
    
    if(multichannel)
    {
    
        //put background of handles to black
        glColor4f(0.0f, 0.0f, 0.0f, 1.0f);
        gl::drawSolidRect(Rectf(-maxTimeSpan,maxVoltsSpan,centerOfCircleX+1.6*radiusXAxis,-maxVoltsSpan));

        //draw all handles
        for(int indexOfChannel = 0;indexOfChannel<maxNumberOfChannels;indexOfChannel++)
        {
            //draw tickmark
            glLineWidth(2.0f);
            glColor4f(1.0f, 1.0f, 1.0f, 1.0-transparencyForAxis);
            gl::drawLine(Vec2f(-maxTimeSpan, yOffsets[indexOfChannel]), Vec2f(-maxTimeSpan+20*scaleXY.x, yOffsets[indexOfChannel]));
            
             //draw handle for active channels
            int colorIndex = [[BBAudioManager bbAudioManager] getColorIndexForActiveChannelIndex:indexOfChannel];
            [self setColorWithIndex:colorIndex transparency:1.0f];

            if(self.mode == MultichannelGLViewModeView || multichannel)
            {
                gl::drawSolidEllipse( Vec2f(centerOfCircleX, yOffsets[indexOfChannel]), radiusXAxis, radiusYAxis, 1000 );
                gl::drawSolidTriangle(
                                      Vec2f(centerOfCircleX+0.35*radiusXAxis, yOffsets[indexOfChannel]+radiusYAxis*0.97),
                                      Vec2f(centerOfCircleX+1.6*radiusXAxis, yOffsets[indexOfChannel]),
                                      Vec2f(centerOfCircleX+0.35*radiusXAxis, yOffsets[indexOfChannel]-radiusYAxis*0.97)
                                      );
            }
            
            //draw line for active channel
            int colorIndex2 = [[BBAudioManager bbAudioManager] getColorIndexForActiveChannelIndex:indexOfChannel];
            [self setColorWithIndex:colorIndex2 transparency:transparencyForAxis];
            glLineWidth(2.0f);
            gl::drawLine(Vec2f(centerOfCircleX, yOffsets[indexOfChannel]), Vec2f(0.0f, yOffsets[indexOfChannel]));
    
            glLineWidth(1.0f);
            
            int colorIndex3 = [[BBAudioManager bbAudioManager] getColorIndexForActiveChannelIndex:indexOfChannel];
            [self setColorWithIndex:colorIndex3 transparency:1.0];
       
            //draw holow unselected handle
            if(indexOfChannel!=selectedChannel)
            {
                glColor4f(0.0f, 0.0f, 0.0f, 1.0f);
                gl::drawSolidEllipse( Vec2f(centerOfCircleX, yOffsets[indexOfChannel]), radiusXAxis*0.8, radiusYAxis*0.8, 1000 );
            }
        }//for loop for channels
    }//if multichannel

    gl::enableDepthRead();
}


-(void) drawEvents
{
    
    
    float currentTime = timeForSincDrawing ;
    
    //NSLog(@"%f",currentTime);
    NSMutableArray * allEvents = [dataSourceDelegate getEvents];
    
    
    float realNumberOfSamplesVisible = numSamplesVisible;
    
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
    
    
    

    glColor4f(1.0f, 0.0f, 0.0f, 1.0f);
    BOOL weAreInInterval = NO;
    BBEvent * tempEvent;
    
    float sizeOfSquareX = 8;
    float sizeOfSquareY = 10;
    //make it so that we can define measurements in pixels
    gl::setMatricesWindow( Vec2i(self.frame.size.width, self.frame.size.height) );
    float lastPositionOfSquareX = -1000;
    float lastPositionOfSquareY = -1000;
    //go through all events
    for (tempEvent in allEvents) {
        if([tempEvent time]>graphStartTime && [tempEvent time]<realEndTime)
        {
            weAreInInterval = YES;//we are in visible interval
            //reacalculate spikes to virtual GL x axis [-maxTimeSpan, 0]
            float xValue = self.frame.size.width+ self.frame.size.width * (([tempEvent time] -realEndTime)/virtualVisibleTimeSpan);
            
            //recalculate Y axis with zoom and offset
            int eventNumber = [tempEvent value];
            float yValueOfNumberBackground = self.frame.size.height/3;
            
            //check if event marks will overlap
            if(abs(xValue-lastPositionOfSquareX)<(2*(sizeOfSquareX+1)))
            {
                if(abs(yValueOfNumberBackground-lastPositionOfSquareY)<sizeOfSquareY)
                {
                    yValueOfNumberBackground = lastPositionOfSquareY+2*sizeOfSquareY+1;
                }
            }
            
            [self setGLColor:[BYBGLView getEventColorWithIndex:eventNumber transparency:1.0f]];

            //draw event line
            gl::drawLine(Vec2f(xValue, -self.frame.size.height), Vec2f(xValue, self.frame.size.height));
            //draw event number background
        gl::drawSolidRect(Rectf(xValue-sizeOfSquareX,yValueOfNumberBackground-sizeOfSquareY,xValue+sizeOfSquareX,yValueOfNumberBackground+sizeOfSquareY));
            
            //Draw event number ---------------------------------------------
            std::stringstream eventStream;
            eventStream <<""<< eventNumber;
            
           
            
            Vec2f xScaleTextPosition = Vec2f(0.,0.);
            xScaleTextPosition.x =xValue-sizeOfSquareX*0.5;
            xScaleTextPosition.y =yValueOfNumberBackground+sizeOfSquareY*0.5;
            
            //make it black number of color background
            gl::color( ColorA( 0.0, 0.0f, 0.0f, 1.0f ) );
            
            //draw text
            mScaleFont->drawString(eventStream.str(), xScaleTextPosition);
            
            lastPositionOfSquareX = xValue;
            lastPositionOfSquareY = yValueOfNumberBackground;
        }
        else if(weAreInInterval)
        {//if we pass last spike in visible interval
            break;
        }
    }
    
    //return back perspective to time and voltage
    mCam.setOrtho(-maxTimeSpan, -0.0f, -maxVoltsSpan/2.0f, maxVoltsSpan/2.0f, 1, 100);
    gl::setMatrices( mCam );
}

//
// Draw spikes of all spike trains
//
-(void) drawSpikes
{
  
    //we use timestamp (timeForSincDrawing) that is taken from audio manager "at the same time"
    //when we took data from circular buffer to display waveform. It is important for sinc of waveform and spike marks
    float currentTime = timeForSincDrawing ;

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
    float thrValueTop;
    float thrValueBottom;
    if([[BBAudioManager bbAudioManager] rtThresholdFirst]>[[BBAudioManager bbAudioManager] rtThresholdSecond])
    {
        thrValueTop = [[BBAudioManager bbAudioManager] rtThresholdFirst];
        thrValueBottom = [[BBAudioManager bbAudioManager] rtThresholdSecond];
    }
    else
    {
        thrValueBottom = [[BBAudioManager bbAudioManager] rtThresholdFirst];
        thrValueTop = [[BBAudioManager bbAudioManager] rtThresholdSecond];
    }
    
    for(int i=0;i<numberOfSpikes;i++)
    {
        if(spikeValues[i]!=0.0f && spikeValues[i]>thrValueBottom && spikeValues[i]<thrValueTop)
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

    
    if(mode == MultichannelGLViewModeThresholding && [[BBAudioManager bbAudioManager] currentFilterSettings]==FILTER_SETTINGS_EKG )//&& [[BBAudioManager bbAudioManager] amDemodulationIsON])
    {
        std::stringstream hearRateText;
        hearRateText << (int)[[BBAudioManager bbAudioManager] heartRate] << "BPM";
        
        Vec2f heartTextSize = heartBeatTextureFont->measureString(hearRateText.str());
        Vec2f heartTextPosition = Vec2f(0.,0.);
        heartTextPosition.x = (self.frame.size.width - heartTextSize.x)/2.0;
        heartTextPosition.y =self.frame.size.height - (mScaleFont->getAscent()* 2.0f)-15;
        
        gl::color( ColorA( 1.0, 0.0f, 0.0f, 1.0f ) );
        gl::enableDepthRead();
        float centerx = self.frame.size.width/2;
        gl::drawSolidRect(Rectf(centerx-3*heartTextSize.y,heartTextPosition.y-1.1*heartTextSize.y,centerx+3*heartTextSize.y,heartTextPosition.y+0.4*heartTextSize.y));
        gl::disableDepthRead();
        
        
        gl::color( ColorA( 1.0, 1.0f, 1.0f, 1.0f ) );
        
        heartBeatTextureFont->drawString(hearRateText.str(), heartTextPosition);
       
    }

   

    float xScale = 0.5*numSamplesVisible*(1/samplingRate)*1000;//1000.0*(xMiddle.x - xFarLeft.x);

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
    
    
    
	gl::color( ColorA( 1.0, 1.0f, 1.0f, 1.0f ) );

  
    //draw x-scale text
    // Now that we have the string, calculate the position of the x-scale text
    // (we'll be horizontally centering by hand)
    Vec2f xScaleTextSize = mScaleFont->measureString(xStringStream.str());
    Vec2f xScaleTextPosition = Vec2f(0.,0.);
    xScaleTextPosition.x = (self.frame.size.width - xScaleTextSize.x)/2.0;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        
        //xScaleTextPosition.y =0.88*self.frame.size.height + (mScaleFont->getAscent() / 2.0f);
        xScaleTextPosition.y =self.frame.size.height - (mScaleFont->getAscent() / 2.0f)-3;
    }
    else
    {
        
        xScaleTextPosition.y =self.frame.size.height - (mScaleFont->getAscent() / 2.0f)-3;//0.95*self.frame.size.height + (mScaleFont->getAscent() / 2.0f);
    }
    mScaleFont->drawString(xStringStream.str(), xScaleTextPosition);
    
    
    gl::enableDepthRead();
    
}


-(void) drawCurrentTime
{
    //show current time label if we are in playback mode
    if(self.mode == MultichannelGLViewModePlayback)
    {
        
        gl::disableDepthRead();
        gl::setMatricesWindow( Vec2i(self.frame.size.width, self.frame.size.height) );
        gl::enableAlphaBlending();
        glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
        //make a string for current time in the file
        std::stringstream currentTimeStringStream;
        
        
        if(([[BBAudioManager bbAudioManager] currentFileTime]/60)<10)
        {
            currentTimeStringStream<<"0";
        }
        currentTimeStringStream<<(int)([[BBAudioManager bbAudioManager] currentFileTime]/60);
        
        currentTimeStringStream<<":";
        
        if((((int)[[BBAudioManager bbAudioManager] currentFileTime])%60)<10)
        {
            currentTimeStringStream<<"0";
        }
        
        currentTimeStringStream<<((int)[[BBAudioManager bbAudioManager] currentFileTime])%60;
        
        Vec2f currentTimeTextPosition = Vec2f(0.,0.);
        currentTimeTextPosition.x = self.frame.size.width - 45 ;
        currentTimeTextPosition.y = self.frame.size.height - 45 - (currentTimeTextureFont->getAscent() / 2.0f);
        currentTimeTextureFont->drawString(currentTimeStringStream.str(), currentTimeTextPosition);
        gl::enableDepthRead();
    }

}



//Draw line for time scale
- (void)drawGrid
{
    //draw line for x-axis
    float left, top, right, bottom, near, far;
    mCam.getFrustum(&left, &top, &right, &bottom, &near, &far);
    //float height = top - bottom;
    float width = right - left;
    float middleX = (right - left)/2.0f + left;

    float lineLength = 0.5*width;

    
    
    float lineY = scaleXY.y*(27*retinaScaling) + bottom;//height*0.1 + bottom;
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
//1 - vertical pinch, 2 - horizontal pinch, 0 no pinch
//
-(int) determinePinchType:(std::vector<ci::app::TouchEvent::Touch>)touches
{
    float thisXDistance = fabs(touches[0].getX() - touches[1].getX());
    float thisYDistance = fabs(touches[0].getY() - touches[1].getY());
    if(thisYDistance>thisXDistance)
    {
        if(thisXDistance<140)
        {
            return 1;
        }
    }
    else
    {
        if(thisYDistance<140)
        {
            return 2;
        }
    }
   // NSLog(@"X: %f,   Y: %f ", thisXDistance, thisYDistance);
    return 0;
}

//
// React on one and two finger gestures
//
- (void)updateActiveTouches
{
    if(!animating)
    {
        return;
    }
    
    [super updateActiveTouches];
    //NSLog(@"Num volts visible: %f", numVoltsVisible[0]);
    
    
    //we added this in case someone touch/pinch screen while unplugging/plugging headphones or similar
    //since display vector will be released and we are accessing diplay vector here from another gesture
    //created thread
    
    std::vector<ci::app::TouchEvent::Touch> touches = [self getActiveTouches];
    
    // Pinching to zoom the display
    if (touches.size() == 2)
    {
        Vec2f touchDistanceDelta = [self calculateTouchDistanceChange:touches];
        float oldNumSamplesVisible = numSamplesVisible;
        float oldNumVoltsVisible = numVoltsVisible[selectedChannel];
     
        //determine pinch type and make zoom mutual exclusive (vertical or horizontal)
        int pinchType = [self determinePinchType:touches];
        switch(pinchType)
        {
                case 1: //vertical pinch
                    touchDistanceDelta.x = 1.0f;
                break;
                case 2: //horizontal pinch
                    touchDistanceDelta.y = 1.0f;
                break;
                default: //diagonal pinch, we don't react on that
                    touchDistanceDelta.x = 1.0f;
                    touchDistanceDelta.y = 1.0f;
                break;
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
        for(int channelIndex = 0;channelIndex<maxNumberOfChannels;channelIndex++)
        {
            vDSP_vsmsa ((float *)&(displayVectors[channelIndex].getPoints()[0]),
                     2,
                     &zoom,
                     &zero,
                     (float *)&(displayVectors[channelIndex].getPoints()[0]),
                     2,
                     numSamplesMax
                     );
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
            float upperBoundary =(maxVoltsSpan*0.5 - HANDLE_RADIUS*HANDLE_RADIUS*scaleXY.y);
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
                        compressedSelectedChannel++;
                    }
                    //Select channel on audio manager
                    [dataSourceDelegate selectChannel:compressedSelectedChannel];
                }
            }
        }
        
       
        
       
        
        //if we are not moving channels check if need to make interval selection or threshold
        if(!weAreHoldingHandle)
        {
            BOOL changingThreshold;
            changingThreshold = false;
            
            //--------------------------------------------------------
            //                  thresholding
            //--------------------------------------------------------
            if (self.mode == MultichannelGLViewModeThresholding && ![dataSourceDelegate selecting]) {

                float zoom = maxVoltsSpan/ numVoltsVisible[selectedChannel];
                float currentThreshold = [dataSourceDelegate threshold]*zoom;

                
                //if threshold is outside the screen we have to react on small handle on top or bottom of the screen
                if([dataSourceDelegate threshold]>(0.4999 *numVoltsVisible[selectedChannel]))
                {
                    //if it is above top set that value is top
                    currentThreshold = 0.4999 *numVoltsVisible[selectedChannel]*zoom;
                }
                else if([dataSourceDelegate threshold]<-(0.4999 *numVoltsVisible[selectedChannel]))
                {
                    //if it is below bottom set that value is bottom
                    currentThreshold = -0.4999 *numVoltsVisible[selectedChannel]*zoom;
                }

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
                    if([[UIScreen mainScreen] respondsToSelector:@selector(scale)] )
                    {
                        windowWidth *= [[UIScreen mainScreen] scale];
                    }
                    float diffPix = touches[0].getPos().x - touches[0].getPrevPos().x;
                    float timeDiff = -diffPix*(numSamplesVisible/windowWidth)*(1/[[BBAudioManager bbAudioManager] sourceSamplingRate]);
                    [[BBAudioManager bbAudioManager] setSeeking:YES];
                    // [[BBAudioManager bbAudioManager] setCurrentFileTime:[[BBAudioManager bbAudioManager] currentFileTime] + timeDiff ];
                     
                     [[BBAudioManager bbAudioManager] setSeekTime:[[BBAudioManager bbAudioManager] currentFileTime] + timeDiff ];
                   
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

-(void) stopAutorange
{
    if(autorangeTimer!=nil)
    {
        autorangeActive = NO;
        [autorangeTimer invalidate];
        autorangeTimer = nil;
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
    if(!multichannel)
    {
        return -1;
    }
    
    
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



#pragma mark - Utility


//
// Calculate position in GL world units based on point in screen pixels
//
- (Vec2f)screenToWorld:(Vec2f)point
{
    
    float windowHeight = self.frame.size.height;
    float windowWidth = self.frame.size.width;
    if([[UIScreen mainScreen] respondsToSelector:@selector(scale)] )
    {
        float screenScale = [[UIScreen mainScreen] scale];//2.0;

        windowHeight *=  screenScale;
        windowWidth *= screenScale;
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
    
    if([[UIScreen mainScreen] respondsToSelector:@selector(scale)] )
    {
        
        
        float screenScale = [[UIScreen mainScreen] scale];//2.0;

        windowHeight *=  screenScale;
        windowWidth *= screenScale;
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
   /* iindex = iindex%5;
    switch (iindex) {
        case 0:
            glColor4f(0.0f, 1.0f, 0.0f, transp);
            break;
        case 1:
            glColor4f(1.0f, 0.011764705882352941f, 0.011764705882352941f, transp);
            break;
        case 2:
            glColor4f( 0.9882352941176471f, 0.9372549019607843f, 0.011764705882352941f, transp);
            break;
        case 3:
            glColor4f(0.9686274509803922f, 0.4980392156862745f, 0.011764705882352941f, transp);
            break;
        case 4:
            glColor4f(1.0f, 0.0f, 1.0f, transp);
            break;
    }
    */
    
    switch (iindex) {
        case 1:
            glColor4f(0.45882352941f,0.98039215686f,0.32156862745f,transp);
            break;
        case 2:
            glColor4f(0.92156862745f,0.2f,0.26666666666f,transp);
            break;
        case 3:
            glColor4f(0.90588235294f,0.98039215686f,0.45882352941f,transp);
            break;
        case 4:
            glColor4f(0.94509803921f,0.56470588235f,0.39607843137f,transp);
            break;
        case 5:
            glColor4f(0.55294117647f,0.89803921568f,0.47843137254f,transp);
            break;
        default:
            glColor4f(0.3294117647f,0.73725490196f,0.77647058823f,transp);
            break;
    }
}




@end
