//
//  DynamicFFTCinderGLView.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/23/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "DynamicFFTCinderGLView.h"
#define X_AXIS_OFFSET 0
#define Y_AXIS_OFFSET 0

@implementation DynamicFFTCinderGLView

//
// Called by super on initWithFrame. It will start animation.
//
- (void)setup
{
    lengthOfFFTData = 1024;
    lengthOfFFTBuffer = 1;
    baseFreq = 12.0;//Hz
    maxFreq = baseFreq*lengthOfFFTData;
    maxTime = 0.01;
    baseTime = 0.01;
    [self enableMultiTouch:YES];
    
    offsetY = 1;
    
    [super setup];//this calls [self startAnimation]
    
    // Setup the camera
	mCam.lookAt( Vec3f(0.0f, 0.0f, 40.0f), Vec3f::zero() );
    
    [self enableAntiAliasing:NO];
    
    // Make sure that we can autorotate 'n what not.
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    // Set up our font, which we'll use to display the unit scales
    mScaleFont = gl::TextureFont::create( Font("Helvetica", 12) );
    
    retinaCorrection = 1.0f;
    if([[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale]==2.0)
    {//if it is retina correct scale
        retinaCorrection = 0.5f;
    }
}

//
// Setup all parameters of view
//
-(void) setupWithBaseFreq:(float) inBaseFreq lengthOfFFT:(UInt32) inLengthOfFFT numberOfGraphs:(UInt32) inNumOfGraphs maxTime:(float) inMaxTime
{
    firstDrawAfterChannelChange = YES;
    [self stopAnimation];
    
    lengthOfFFTData = inLengthOfFFT;
    lengthOfFFTBuffer = inNumOfGraphs;
    
    float tempNumberOfPix = lengthOfFFTData*lengthOfFFTBuffer;
    float tempOverload = 11825.0f/tempNumberOfPix;
    int newFreq = lengthOfFFTData*tempOverload;
    
    
    baseFreq = inBaseFreq;
    baseTime = inMaxTime/(float) inNumOfGraphs;
    
    maxFreq = baseFreq*( lengthOfFFTData>newFreq?newFreq:lengthOfFFTData);
    maxTime = inMaxTime;
    
    currentMaxFreq = maxFreq;
    currentMaxTime = maxTime;
    
    [self calculateScale];
    

    
    [self startAnimation];
}

-(void) calculateScale
{
    scaleXY = [self screenToWorld:Vec2f(1.0f,1.0f)];
    Vec2f scaleXYZero = [self screenToWorld:Vec2f(0.0f,0.0f)];
    scaleXY.x = fabsf(scaleXY.x - scaleXYZero.x);
    scaleXY.y = fabsf(scaleXY.y - scaleXYZero.y);
}

-(void) calculateAxisIntervals
{
    uint32_t log10n = log10f(currentMaxFreq*0.7);
    markIntervalYAxis = powf(10,log10n);
    markIntervalYAxis/=10.0;
    
    log10n = log10f(currentMaxTime*0.7);
    markIntervalXAxis = powf(10,log10n);
    markIntervalXAxis/=10.0;
}

//
// Draw graph
//
- (void)draw {
    
    float ** graphBuffer = [[BBAudioManager bbAudioManager] getDynamicFFTResult];
    if(graphBuffer)
    {
        if(firstDrawAfterChannelChange)
        {
            //this is fix for bug. Draw text starts to paint background of text
            //to the same color as text if we don't make new instance here
            //TODO: find a reason for this
            firstDrawAfterChannelChange = NO;
            mScaleFont = gl::TextureFont::create( Font("Helvetica", 12) );
        }
        
        // this pair of lines is the standard way to clear the screen in OpenGL
        gl::clear( Color( 0.0f, 0.0f, 0.0f ), true );
        glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
        
        
        // Look at it right
        mCam.setOrtho(-currentMaxTime, 0, 0, currentMaxFreq, 1, 100);
        gl::setMatrices( mCam );
        
        [self calculateScale];
        [self calculateAxisIntervals];
        
        offsetX = X_AXIS_OFFSET* scaleXY.x/(2*retinaCorrection);
        offsetY = Y_AXIS_OFFSET* scaleXY.y/(2*retinaCorrection);
        
        int indexOfGraphs = [[BBAudioManager bbAudioManager] indexOfFFTGraphBuffer];
        
        glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
        glLineWidth(10.0f);
        float currTime = 0;
        float currFreq = 0;
        float normPower;
        int freqIndex;
        Rectf tempRect = Rectf(0.0,0.0,0.0,0.0);
        float * holderOfFreqGraph;
        float redC = 0;
        float oldRedC = 0;
        float greenC = 0;
        float oldGreernC=0;
        float blueC=0;
        float oldBlueC=0;
        float endOfTime = -currentMaxTime+offsetX;
        for(currTime=0.0;currTime>endOfTime;currTime-=baseTime)
        {
            indexOfGraphs--;
            if(indexOfGraphs<0)
            {
                indexOfGraphs = lengthOfFFTBuffer-1;
            }

            freqIndex = 0;
            tempRect.x1 = currTime;
            tempRect.x2 = currTime-baseTime;
            if(tempRect.x2<endOfTime)
            {
                tempRect.x2 = endOfTime;
            }
            holderOfFreqGraph = graphBuffer[indexOfGraphs];
            for(currFreq = offsetY;currFreq<currentMaxFreq;currFreq=currFreq)
            {
            
                normPower = holderOfFreqGraph[freqIndex];
                //glColor4f(normPower, normPower, normPower, 1.0f);
                redC = red(normPower);
                greenC = green(normPower);
                blueC = blue(normPower);
                if(redC!=oldRedC || greenC!=oldGreernC || blueC != oldBlueC)
                {
                    glColor4f(redC, greenC, blueC, 1.0f);
                    oldBlueC = blueC;
                    oldRedC = redC;
                    oldGreernC = greenC;
                }
                tempRect.y1 = currFreq;
                currFreq+=baseFreq;
                tempRect.y2 = currFreq;
                gl::drawSolidRect(tempRect);
                freqIndex++;
            }
        }
        
        
        
        // Marks for X axis - Time
        float markPos=0;
        float sizeOfMark = 10* scaleXY.y/(2*retinaCorrection);
        float thirdOfMark = sizeOfMark*0.33;
        float twoThirdOfMark = sizeOfMark*0.66;
        
        glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
        glLineWidth(2.0f);
        int i=0;
        for(i=0;i<170;i++)
        {
            if(i%10==0)
            {
                gl::drawLine(Vec2f(markPos, currentMaxFreq-sizeOfMark), Vec2f(markPos, currentMaxFreq));
            }
            else if (i%5==0)
            {
                gl::drawLine(Vec2f(markPos, currentMaxFreq-twoThirdOfMark), Vec2f(markPos, currentMaxFreq));
            }
            else
            {
                gl::drawLine(Vec2f(markPos, currentMaxFreq-thirdOfMark), Vec2f(markPos, currentMaxFreq));
            }
            
            markPos-=markIntervalXAxis;
            if(markPos<(offsetX-currentMaxTime) )
            {
                break;
            }
        }
        
        
        //Mark for Y axis frequency
        markPos=offsetY;
        sizeOfMark = 10* scaleXY.x/(2*retinaCorrection);
        thirdOfMark = sizeOfMark*0.33;
        twoThirdOfMark = sizeOfMark*0.66;
        
        for(i=0;i<170;i++)
        {
            if(i%10==0)
            {
                gl::drawLine(Vec2f(endOfTime+sizeOfMark, markPos), Vec2f(endOfTime, markPos));
            }
            else if (i%5==0)
            {
                gl::drawLine(Vec2f(endOfTime+twoThirdOfMark,markPos), Vec2f(endOfTime, markPos));
            }
            else
            {
                gl::drawLine(Vec2f(endOfTime+thirdOfMark, markPos), Vec2f(endOfTime, markPos));
            }
            
            markPos+=markIntervalYAxis;
        }
        
        
        //========== Draw scale text ==================
        
        //Text for X axis - Time
        
        gl::disableDepthRead();
        gl::setMatricesWindow( Vec2i(self.frame.size.width, self.frame.size.height) );
        gl::enableAlphaBlending();
        
        markPos=0.0;
        std::stringstream hzString;
        hzString.precision(1);
        Vec2f xScaleTextSize;
        Vec2f xScaleTextPosition = Vec2f(0.,0.);
        glLineWidth(2.0f);
        for(i=0;i<17;i++)
        {
            //draw number
            
            hzString.str("");
            hzString << fixed << (int)-markPos;
            xScaleTextSize = mScaleFont->measureString(hzString.str());
            if(i!=0)
            {
                xScaleTextPosition.x = self.frame.size.width+(markPos/scaleXY.x)*retinaCorrection -xScaleTextSize.x*0.5 ;
            }
            else
            {
                xScaleTextPosition.x = self.frame.size.width +(markPos/scaleXY.x)*retinaCorrection;
            }
            xScaleTextPosition.y =15;
            if(xScaleTextPosition.x>20)
            {
                mScaleFont->drawString(hzString.str(), xScaleTextPosition);
            }
            else
            {
                break;
            }
            markPos-=10*markIntervalXAxis;
        }
        
        hzString.str("");
        hzString << fixed << "Time (S)";
        xScaleTextSize = mScaleFont->measureString(hzString.str());
        
        xScaleTextPosition.x = self.frame.size.width - xScaleTextSize.x*1.5 ;
        
        xScaleTextPosition.y =35;
        mScaleFont->drawString(hzString.str(), xScaleTextPosition);
        
        
        
        //Text for Y axis - Frequency
        
        markPos=offsetY;
        hzString.precision(1);
        glLineWidth(2.0f);
        for(i=0;i<17;i++)
        {
            //draw number
            
            hzString.str("");
            hzString << fixed << (int)(markPos-offsetY);
            xScaleTextSize = mScaleFont->measureString(hzString.str());
            if(i!=0)
            {
                xScaleTextPosition.y = self.frame.size.height-(markPos/scaleXY.y)*retinaCorrection + xScaleTextSize.y*0.5 ;
            }
            else
            {
                xScaleTextPosition.y = self.frame.size.height - (markPos/scaleXY.y)*retinaCorrection+ xScaleTextSize.y;
            }
            xScaleTextPosition.x =15;
            if(xScaleTextPosition.y>30)
            {
                mScaleFont->drawString(hzString.str(), xScaleTextPosition);
            }
            else
            {
                break;
            }
            markPos+=10*markIntervalYAxis;
        }
        
        hzString.str("");
        hzString << fixed << "Hz";
        xScaleTextSize = mScaleFont->measureString(hzString.str());
        
        xScaleTextPosition.x = X_AXIS_OFFSET*retinaCorrection*1.4 ;
        
        xScaleTextPosition.y =25;
        //mScaleFont->drawString(hzString.str(), xScaleTextPosition);
        
        
        
       /*
        
        //========== Draw scale text ==================
        
        gl::disableDepthRead();
        gl::setMatricesWindow( Vec2i(self.frame.size.width, self.frame.size.height) );
        gl::enableAlphaBlending();
        
        markPos=0;
        std::stringstream hzString;
        hzString.precision(1);
        Vec2f xScaleTextSize;
        Vec2f xScaleTextPosition = Vec2f(0.,0.);
        glLineWidth(2.0f);
        for(i=0;i<10;i++)
        {
            //draw number
            
            hzString.str("");
            hzString << fixed << (int)markPos;
            xScaleTextSize = mScaleFont->measureString(hzString.str());
            if(i!=0)
            {
                xScaleTextPosition.x = (markPos/scaleXY.x)*retinaCorrection -xScaleTextSize.x*0.5 ;
            }
            else
            {
                xScaleTextPosition.x = (markPos/scaleXY.x)*retinaCorrection;
            }
            xScaleTextPosition.y =self.frame.size.height-37;
            mScaleFont->drawString(hzString.str(), xScaleTextPosition);
            markPos+=10*markIntervalXAxis;
        }
        
        hzString.str("");
        hzString << fixed << "Frequency (Hz)";
        xScaleTextSize = mScaleFont->measureString(hzString.str());
        
        xScaleTextPosition.x = 0.5f*self.frame.size.width - xScaleTextSize.x*0.5 ;
        
        xScaleTextPosition.y =self.frame.size.height- 15;
        mScaleFont->drawString(hzString.str(), xScaleTextPosition);*/
        
    }
}

//====================================== TOUCH ===================
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
    
    
    std::vector<ci::app::TouchEvent::Touch> touches = [self getActiveTouches];
    
    // Pinching to zoom the display
    if (touches.size() == 2)
    {
        Vec2f touchDistanceDelta = [self calculateTouchDistanceChange:touches];
        float oldMaxFreq = currentMaxFreq;
        float oldMaxTime = currentMaxTime;
        currentMaxTime /= (sqrtf(touchDistanceDelta.x) - 1) + 1;
        currentMaxFreq /= (sqrtf(touchDistanceDelta.y) - 1) + 1;
        
        // Make sure that we don't go out of bounds
        if (currentMaxFreq < baseFreq )
        {
            currentMaxFreq = oldMaxFreq;
        }
        if (currentMaxFreq > maxFreq)
        {
            currentMaxFreq = maxFreq;
        }
        
        if (currentMaxTime < 1.1 )
        {
            currentMaxTime = 1.1;
        }
        
        if(currentMaxTime>maxTime)
        {
            currentMaxTime = maxTime;
        }
    }
    
    // Touching to change the threshold value, if we're thresholding
    //Selecting time interval and thresholding are mutualy exclusive
    else if (touches.size() == 1)
    {
        
        
        
    }
    
}



#pragma mark - Utility

float interpolate( float val, float y0, float x0, float y1, float x1 ) {
    return (val-x0)*(y1-y0)/(x1-x0) + y0;
}

float base( float val ) {
    if ( val <= -0.75 ) return 0;
    else if ( val <= -0.25 ) return interpolate( val, 0.0, -0.75, 1.0, -0.25 );
    else if ( val <= 0.25 ) return 1.0;
    else if ( val <= 0.75 ) return interpolate( val, 1.0, 0.25, 0.0, 0.75 );
    else return 0.0;
}

float red( float gray ) {
    return base( gray - 0.5 );
}
float green( float gray ) {
    return base( gray );
}
float blue( float gray ) {
    return base( gray + 0.5 );
}


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


@end
