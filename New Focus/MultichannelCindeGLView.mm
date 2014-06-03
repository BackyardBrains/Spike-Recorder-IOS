//
//  MultichannelCindeGLView.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 5/28/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "MultichannelCindeGLView.h"
#import <Accelerate/Accelerate.h>
#define HANDLE_RADIUS 20

@interface MultichannelCindeGLView ()
{
   
    float * tempDataBuffer; //data buffer that is used to transfer data (modify stride) to displayVectors
    int selectedChannel;//current selected channel
    float maxTimeSpan;//max time
    float maxVoltsSpan;//max volts
    BOOL multichannel;//flag for multichannel logic
   
    //precalculated constants
    Vec2f scaleXY;//relationship between pixels and GL world (pixels x scaleXY = GL units)
 
    
    
    //debug variables
    BOOL debugMultichannelOnSingleChannel;
}

@end


@implementation MultichannelCindeGLView

@synthesize mode;//operational mode - enum MultichannelGLViewMode

//====================================== INIT ==============================================================================
#pragma mark - Initialization
//
// Called by super on initWithFrame. It will start animation.
//
- (void)setup
{
    debugMultichannelOnSingleChannel = NO;
    
    dataSourceDelegate = nil;;
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
    mScaleFont = gl::TextureFont::create( Font("Helvetica", 18) );
    
}


//
// Function setup view to display newNumberOfChannels channels with samling rate of newSamplingRate and
// it will get data using MultichannelGLViewDelegate protocol from newDataSource.
//
- (void)setNumberOfChannels:(int) newNumberOfChannels samplingRate:(float) newSamplingRate andDataSource:(id <MultichannelGLViewDelegate>) newDataSource
{
    [self stopAnimation];
    
    if(newNumberOfChannels<2)
    {
        debugMultichannelOnSingleChannel = YES;
        newNumberOfChannels = 3;
    }
    
    dataSourceDelegate = newDataSource;
    samplingRate = newSamplingRate;
    numberOfChannels = newNumberOfChannels;
    
    if(numberOfChannels>1)
    {
        multichannel = YES;
    }
    
    selectedChannel = 0;
    
    // Setup display vectors. Every PolyLine2f is one waveform
    if(displayVectors!=nil)
    {
        //TODO: realease display vectors
        delete[] displayVectors;
        delete[] numSamplesVisible;
        delete[] numVoltsVisible;
        delete[] yOffsets;
        delete[] tempDataBuffer;
    }
    displayVectors =  new PolyLine2f[newNumberOfChannels];
    numSamplesVisible = new float[newNumberOfChannels]; // current zoom for every channel x axis
    numVoltsVisible = new float[newNumberOfChannels]; //current zoom for every channel y axis
    yOffsets = new float[newNumberOfChannels];//y offset of horizontal axis

    
    //load limits for graph and init starting position
    [self loadSettings:FALSE];
    
    
    //data buffer that is used to transfer data (modify stride) to displayVectors
    tempDataBuffer = new float[numSamplesMax];

    maxTimeSpan = ((float)numSamplesMax)/newSamplingRate;

    //4 milivolts will be screen size
    maxVoltsSpan = 0.008;
    
    
    //create vetors that hold waveforms for every channel
    //we will create X axis values now and afterwards we will change Y values in every frame
    // and X axis values on zoom in/ zoom out
    for(int channelIndex = 0; channelIndex < numberOfChannels; channelIndex++)
    {
        
        float oneSampleTime = maxTimeSpan / numSamplesVisible[selectedChannel];
        for (int i=0; i <numSamplesMax-1; i++)
        {
            float x = (i- (numSamplesMax-1))*oneSampleTime;
            displayVectors[channelIndex].push_back(Vec2f(x, 0.0f));
        }
        displayVectors[channelIndex].setClosed(false);
        
        yOffsets[channelIndex] = -maxVoltsSpan*0.5 + (channelIndex+1)*(maxVoltsSpan/((float)numberOfChannels))- 0.5*(maxVoltsSpan/((float)numberOfChannels));
        
    }			

    
    
    [self startAnimation];
}

- (void)loadSettings:(BOOL)useThresholdSettings
{
    
    NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Initialize parameters
    if (useThresholdSettings) {
        NSLog(@"Setting threshold defaults");
        numSamplesMax = [[defaults valueForKey:@"numSamplesMax"] floatValue];
        numSamplesMin = [[defaults valueForKey:@"numSamplesMin"] floatValue];
        
        for(int i=0;i<numberOfChannels;i++)
        {
            numSamplesVisible[i] = [[defaults valueForKey:@"numSamplesVisibleThreshold"] floatValue];
        }
        
        numVoltsMin = [[defaults valueForKey:@"numVoltsMinThreshold"] floatValue];
        numVoltsMax = [[defaults valueForKey:@"numVoltsMaxThreshold"] floatValue];
       
        for(int i=0;i<numberOfChannels;i++)
        {
            numVoltsVisible[i] = [[defaults valueForKey:@"numVoltsVisibleThreshold"] floatValue];
        }
    }
    else {
        numSamplesMax = [[defaults valueForKey:@"numSamplesMax"] floatValue];
        numSamplesMin = [[defaults valueForKey:@"numSamplesMin"] floatValue];
        for(int i=0;i<numberOfChannels;i++)
        {
            numSamplesVisible[i] = [[defaults valueForKey:@"numSamplesVisible"] floatValue];
        }
        numVoltsMin = [[defaults valueForKey:@"numVoltsMin"] floatValue];
        numVoltsMax = [[defaults valueForKey:@"numVoltsMax"] floatValue];
        
        for(int i=0;i<numberOfChannels;i++)
        {
            numVoltsVisible[i] = [[defaults valueForKey:@"numVoltsVisible"] floatValue];
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
        [defaults setValue:[NSNumber numberWithFloat:numSamplesMax] forKey:@"numSamplesMax"];
        [defaults setValue:[NSNumber numberWithFloat:numSamplesMin] forKey:@"numSamplesMin"];
        [defaults setValue:[NSNumber numberWithFloat:numSamplesVisible[0]] forKey:@"numSamplesVisibleThreshold"];
        [defaults setValue:[NSNumber numberWithFloat:numVoltsMin] forKey:@"numVoltsMinThreshold"];
        [defaults setValue:[NSNumber numberWithFloat:numVoltsMax] forKey:@"numVoltsMaxThreshold"];
        [defaults setValue:[NSNumber numberWithFloat:numVoltsVisible[0]] forKey:@"numVoltsVisibleThreshold"];
    }
    else {
        [defaults setValue:[NSNumber numberWithFloat:numSamplesMax] forKey:@"numSamplesMax"];
        [defaults setValue:[NSNumber numberWithFloat:numSamplesMin] forKey:@"numSamplesMin"];
        [defaults setValue:[NSNumber numberWithFloat:numSamplesVisible[0]] forKey:@"numSamplesVisible"];
        [defaults setValue:[NSNumber numberWithFloat:numVoltsMin] forKey:@"numVoltsMin"];
        [defaults setValue:[NSNumber numberWithFloat:numVoltsMax] forKey:@"numVoltsMax"];
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
    for(int channelIndex = 0; channelIndex<numberOfChannels; channelIndex++)
    {
        // See if we're asking for TOO MANY points
        int numPoints, offset;
        if (numSamplesVisible[channelIndex] > numSamplesMax) {
            numPoints = numSamplesMax;
            offset = 0;
            
            if ([self getActiveTouches].size() != 2)
            {
                float oldValue = numSamplesVisible[channelIndex];
                numSamplesVisible[channelIndex] += 0.6 * (numSamplesMax - numSamplesVisible[channelIndex]);
                
                float zero = 0.0f;
                float zoom = oldValue/numSamplesVisible[channelIndex];
                vDSP_vsmsa ((float *)&(displayVectors[channelIndex].getPoints()[0]), 2,
                            &zoom,
                            &zero,
                            (float *)&(displayVectors[channelIndex].getPoints()[0]),
                            2,
                            numSamplesMax
                            );
            }
        }
        
        // See if we're asking for TOO FEW points
        else if (numSamplesVisible[channelIndex] < numSamplesMin)
        {
            
            numPoints = numSamplesMin;
            offset = 0;
            
            if ([self getActiveTouches].size() != 2)
            {
                
                float oldValue = numSamplesVisible[channelIndex];
                numSamplesVisible[channelIndex] += 0.6 * (numSamplesMin*2.0 - numSamplesVisible[channelIndex]);//animation to min sec
                
                float zero = 0.0f;
                float zoom = oldValue/numSamplesVisible[channelIndex];
                vDSP_vsmsa ((float *)&(displayVectors[channelIndex].getPoints()[0]), 2,
                            &zoom,
                            &zero,
                            (float *)&(displayVectors[channelIndex].getPoints()[0]),
                            2,
                            numSamplesMax
                            );

            }
        }
        
        // If we haven't set off any of the alarms above,
        // then we're asking for a normal range of points.
        else {
            numPoints = numSamplesVisible[channelIndex];//visible part
            offset = numSamplesMax - numPoints;//nonvisible part
            
            if (self.mode == MultichannelGLViewModeThresholding) {
                offset -= (numSamplesMin)/2.0f;
            }
        }

        // Aight, now that we've got our ranges correct, let's ask for the signal.
        //Only fetch visible part (numPoints samples) and put it after offset.
        //TODO: timeForSincDrawing is used to sinc displaying of waveform and spike marks
       
        //================ debug region ======
        if(debugMultichannelOnSingleChannel)
        {
            
            [dataSourceDelegate fetchDataToDisplay:tempDataBuffer numFrames:numPoints whichChannel:0];
        }
        else
        {
        //================ end debug region ======
            [dataSourceDelegate fetchDataToDisplay:tempDataBuffer numFrames:numPoints whichChannel:channelIndex];
        //================ debug region ======
        }
        //================ end debug region ======

        //now transfer y axis data from bufer to display vector with stride equ. to 2
        //multiply Y data with zoom level
        
        float zero = yOffsets[channelIndex];
        float zoom = maxVoltsSpan/ numVoltsVisible[channelIndex];
        //float zoom = 1.0f;
        vDSP_vsmsa (tempDataBuffer,
                    1,
                    &zoom,
                    &zero,
                    (float *)&(displayVectors[channelIndex].getPoints()[offset])+1,
                    2,
                    numSamplesMax
                    );
        
        
        //NSLog(@"v: %f %f", displayVectors[channelIndex].getPoints()[0].x, displayVectors[channelIndex].getPoints()[offset].x);
        //timeForSincDrawing =  [audioManager fetchAudio:(float *)&(displayVector.getPoints()[offset])+1 numFrames:numPoints whichChannel:0 stride:2];
    }
}



- (void)draw {
    
    
    // this pair of lines is the standard way to clear the screen in OpenGL
	gl::clear( Color( 0.0f, 0.0f, 0.0f ), true );
	glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    
    if(dataSourceDelegate)
    {
        // Look at it right
        mCam.setOrtho(-maxTimeSpan, -0.0f, -maxVoltsSpan/2.0f, maxVoltsSpan/2.0f, 1, 100);
        gl::setMatrices( mCam );
        
        scaleXY = [self screenToWorld:Vec2f(1.0f,1.0f)];
        Vec2f scaleXYZero = [self screenToWorld:Vec2f(0.0f,0.0f)];
        scaleXY.x = fabsf(scaleXY.x - scaleXYZero.x);
        scaleXY.y = fabsf(scaleXY.y - scaleXYZero.y);
        
        
        
        // Set the line color and width
        glColor4f(0.0f, 1.0f, 0.0f, 1.0f);
        glLineWidth(1.0f);
        
        // Put the audio on the screen
        gl::disableDepthRead();
        [self fillDisplayVector];
        for(int channelIndex=0;channelIndex<numberOfChannels;channelIndex++)
        {
            [self setColorWithIndex:channelIndex transparency:1.0f];
            gl::draw(displayVectors[channelIndex]);

        }
        
        if(multichannel)
        {
            //draw handle
            
            [self drawHandles];
            
        }
        
        // Put a little grid on the screen.
        [self drawGrid];
        
        // Draw some text on that screen
        [self drawScaleTextAndSelected];
    }
}

//
// Draw handles for axis
//
-(void) drawHandles
{
    float centerOfCircleX = -maxTimeSpan+20*scaleXY.x;

    float radiusXAxis = HANDLE_RADIUS*scaleXY.x;
    float radiusYAxis = HANDLE_RADIUS*scaleXY.y;

    

    glColor4f(0.0f, 0.0f, 0.0f, 1.0f);
    gl::drawSolidRect(Rectf(-maxTimeSpan,maxVoltsSpan,centerOfCircleX+1.6*radiusXAxis,-maxVoltsSpan));

    
    for(int indexOfChannel = 0;indexOfChannel<numberOfChannels;indexOfChannel++)
    {
        [self setColorWithIndex:indexOfChannel transparency:1.0f];
        gl::drawSolidEllipse( Vec2f(centerOfCircleX, yOffsets[indexOfChannel]), radiusXAxis, radiusYAxis, 1000 );
        gl::drawSolidTriangle(
                              Vec2f(centerOfCircleX+0.35*radiusXAxis, yOffsets[indexOfChannel]+radiusYAxis*0.97),
                              Vec2f(centerOfCircleX+1.6*radiusXAxis, yOffsets[indexOfChannel]),
                              Vec2f(centerOfCircleX+0.35*radiusXAxis, yOffsets[indexOfChannel]-radiusYAxis*0.97)
                              );
        
        
        glLineWidth(2.0f);
        gl::drawLine(Vec2f(centerOfCircleX, yOffsets[indexOfChannel]), Vec2f(0.0f, yOffsets[indexOfChannel]));
        glLineWidth(1.0f);
        if(indexOfChannel!=selectedChannel)
        {
            glColor4f(0.0f, 0.0f, 0.0f, 1.0f);
            gl::drawSolidEllipse( Vec2f(centerOfCircleX, yOffsets[indexOfChannel]), radiusXAxis*0.8, radiusYAxis*0.8, 1000 );
        }

    }
    gl::enableDepthRead();
}


//TODO:Update for all states
- (void)drawScaleTextAndSelected
{
    gl::disableDepthRead();
    gl::setMatricesWindow( Vec2i(self.frame.size.width, self.frame.size.height) );
	gl::enableAlphaBlending();
    
    // Calculate the position of the y-scale text to be shown
    Vec2f yScaleTextPosition = Vec2f(20.0, self.frame.size.height/2.0f - 120.0f + (mScaleFont->getAscent() / 2.0f));
    
    // Now, calculate the values to be placed in the text
    Vec2f xFarLeft = [self screenToWorld:Vec2f(0.0, 0.0)];
    Vec2f xMiddle  = [self screenToWorld:Vec2f(self.frame.size.width/2.0f, 0.0)];
    Vec2f yScaleWorldPosition = [self screenToWorld:yScaleTextPosition];
    
    float xScale = 0.5*numSamplesVisible[selectedChannel]*(1/samplingRate)*1000;//1000.0*(xMiddle.x - xFarLeft.x);
    float yScale = yScaleWorldPosition.y;
    /*if([[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale]==2.0)
    {//if it is retina correct scale
        //TODO: This should be tested with calibration voltage source
        xScale *= 2.0f;
        yScale /=2.0f;
    }*/
    
    
    // Figure out what we want to say
    std::ostringstream yStringStream;
    yStringStream.precision(2);
    yStringStream << fixed << yScale << " mV";
    
    
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
     xStringStream << fixed << br << " KSps";
     }
     else {
     xStringStream << fixed << br << " Sps";
     }*/
    //==================================================
    
    
	gl::color( ColorA( 1.0, 1.0f, 1.0f, 1.0f ) );
    
    
    // Draw the y-axis scale text
    
// mScaleFont->drawString(yStringStream.str(), yScaleTextPosition);
  
    //If we are not measuring draw x-scale text
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




//TODO:Update for all states
- (void)drawGrid
{
    //draw line for x-axis
    float left, top, right, bottom, near, far;
    mCam.getFrustum(&left, &top, &right, &bottom, &near, &far);
    float height = top - bottom;
    float width = right - left;
    float middleX = (right - left)/2.0f + left;
    //draw line for x-axis if we are not displaying time interval measure
   // if (!weAreDrawingSelection) {
        float lineLength = 0.5*width;
        float lineY = height*0.1 + bottom;
        Vec2f leftPoint = Vec2f(middleX - lineLength / 2.0f, lineY);
        Vec2f rightPoint = Vec2f(middleX + lineLength / 2.0f, lineY);
        glColor4f(0.8, 0.8, 0.8, 1.0);
        glLineWidth(1.0f);
        gl::drawLine(leftPoint, rightPoint);
   // }
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
//
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
        float oldNumSamplesVisible = numSamplesVisible[selectedChannel];
        float oldNumVoltsVisible = numVoltsVisible[selectedChannel];
        numSamplesVisible[selectedChannel] /= (touchDistanceDelta.x - 1) + 1;
        numVoltsVisible[selectedChannel] /= (touchDistanceDelta.y - 1) + 1;
       
        // Make sure that we don't go out of bounds
        if (numSamplesVisible[selectedChannel] < numSamplesMin )
        {
            touchDistanceDelta.x = 1.0f;
            numSamplesVisible[selectedChannel] = oldNumSamplesVisible;
        }
        if (numVoltsVisible[selectedChannel] < 0.001)
        {
            touchDistanceDelta.y = 1.0f;
            numVoltsVisible[selectedChannel] = oldNumVoltsVisible;
        }
        
       
        //Change x axis values so that only numSamplesVisible[selectedChannel] samples are visible for selected channel
        float zero = 0.0f;
        float zoom = touchDistanceDelta.x;
        vDSP_vsmsa ((float *)&(displayVectors[selectedChannel].getPoints()[0]), 2,
                         &zoom,
                         &zero,
                         (float *)&(displayVectors[selectedChannel].getPoints()[0]),
                         2,
                         numSamplesMax
                         );
       
    }
    
    // Touching to change the threshold value, if we're thresholding
    //Selecting time interval and thresholding are mutualy exclusive
    else if (touches.size() == 1)
    {
        Vec2f touchPos = touches[0].getPos();
        // Convert into GL coordinate
        Vec2f glWorldTouchPos = [self screenToWorld:touchPos];
        int grabbedHandleIndex;
        
        //if user grabbed the handle of channel
        if(multichannel && (grabbedHandleIndex = [self checkIntersectionWithHandles:glWorldTouchPos])!=-1)
        {
            //move channel
            yOffsets[grabbedHandleIndex] = glWorldTouchPos.y;
            
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
            selectedChannel = grabbedHandleIndex;
        
        }
    }
    
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
    for(int channelIndex=0;channelIndex<numberOfChannels;channelIndex++)
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



/*- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event
{
    //if touch begins remove old time interval selection
    [[BBAudioManager bbAudioManager] endSelection];
    [super touchesBegan:touches withEvent:event];
    
}

- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event
{
    //if user just tapped on screen start and end point will
    //be the same so we will remove time interval selection
    if([[BBAudioManager bbAudioManager] selectionStartTime] == [[BBAudioManager bbAudioManager] selectionEndTime])
    {
        [[BBAudioManager bbAudioManager] endSelection];
    }
    [super touchesEnded:touches withEvent:event];
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
