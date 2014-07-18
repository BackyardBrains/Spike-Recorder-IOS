//
//  FFTCinderGLView.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 7/16/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "FFTCinderGLView.h"
#define X_AXIS_OFFSET 120

@implementation FFTCinderGLView

//
// Called by super on initWithFrame. It will start animation.
//
- (void)setup
{
    lengthOfFFTData = 1024;
    baseFreq = 12.0;//Hz
    maxFreq = baseFreq*lengthOfFFTData;
    maxPow = 10;
    
    [self enableMultiTouch:YES];
    
    offsetY = 1;
    
    [super setup];//this calls [self startAnimation]
    
    // Setup the camera
	mCam.lookAt( Vec3f(0.0f, 0.0f, 40.0f), Vec3f::zero() );
    
    [self enableAntiAliasing:YES];
    
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
-(void) setupWithBaseFreq:(float) inBaseFreq andLengthOfFFT:(UInt32) inLengthOfFFT
{
    firstDrawAfterChannelChange = YES;
    [self stopAnimation];
    
    lengthOfFFTData = inLengthOfFFT;
    baseFreq = inBaseFreq;
    
    maxFreq = baseFreq*lengthOfFFTData;
    currentMaxFreq = maxFreq;
    maxPow = 10;
    currentMaxPow = maxPow;
    
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

-(void) calculateXAxisFreq
{
    uint32_t log10n = log10f(currentMaxFreq);
    markIntervalXAxis = powf(10,log10n);
    markIntervalXAxis/=10.0;
}

//
// Draw graph
//
- (void)draw {
    
    float * powBuffer = [[BBAudioManager bbAudioManager] getFFTResult];
    if(powBuffer)
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
        mCam.setOrtho(0, currentMaxFreq, 0, currentMaxPow, 1, 100);
        gl::setMatrices( mCam );
        
        [self calculateScale];
        [self calculateXAxisFreq];
        

        offsetY = X_AXIS_OFFSET* scaleXY.y/(2*retinaCorrection);
        
        
        // Set the line color and width
        glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
        glLineWidth(1.0f);
        float currFreq = 0;
        float * powBuffer = [[BBAudioManager bbAudioManager] getFFTResult];
        int i=0;
        for(currFreq=0.0;currFreq<maxFreq;currFreq+=baseFreq)
        {
            if(currFreq>0.1 && currFreq<=3.5)
            {
                //delta
                glColor4f(0.9686274509803922f, 0.4980392156862745f, 0.011764705882352941f, 1.0);
            }
            else if (currFreq>3.5 && currFreq<=7.5)
            {
                //theta
                glColor4f(1.0f, 0.011764705882352941f, 0.011764705882352941f, 1.0);
            }
            else if (currFreq>7.5 && currFreq<=15.5)
            {
                //alpha
                glColor4f( 0.9882352941176471f, 0.9372549019607843f, 0.011764705882352941f, 1.0);
            }
            else if (currFreq>15.5 && currFreq<=31.5)
            {
                //beta
                glColor4f(0.0f, 0.0f, 1.0f, 1.0);
            }
            else if (currFreq>31.5 && currFreq<=100)
            {
                //gama
                glColor4f(1.0f, 0.0f, 1.0f, 1.0);
            }
            else
            {
                glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
            }
            
            gl::drawSolidRect(Rectf(currFreq,offsetY, currFreq+baseFreq,powBuffer[i]+offsetY));
            i++;
        }
        float markPos=0;
        float thirdOfMark = offsetY*0.05;
        float twoThirdOfMark = offsetY*0.1;
        float sizeOfMark = offsetY*0.15;
        glLineWidth(2.0f);
        for(i=0;i<100;i++)
        {
            if(i%10==0)
            {
                gl::drawLine(Vec2f(markPos, offsetY-sizeOfMark), Vec2f(markPos, offsetY));
            }
            else if (i%5==0)
            {
                gl::drawLine(Vec2f(markPos, offsetY-twoThirdOfMark), Vec2f(markPos, offsetY));
            }
            else
            {
                gl::drawLine(Vec2f(markPos, offsetY-thirdOfMark), Vec2f(markPos, offsetY));
            }
            
            markPos+=markIntervalXAxis;
        }
        
        
        
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
        mScaleFont->drawString(hzString.str(), xScaleTextPosition);
        
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
        currentMaxFreq /= (touchDistanceDelta.x - 1) + 1;
        currentMaxPow /= (touchDistanceDelta.y - 1) + 1;
        
        // Make sure that we don't go out of bounds
        if (currentMaxFreq < baseFreq )
        {
            currentMaxFreq = oldMaxFreq;
        }
        if (currentMaxFreq > maxFreq)
        {
            currentMaxFreq = maxFreq;
        }
        
        if (currentMaxPow < 0.01 )
        {
            currentMaxPow = 0.01;
        }
    }
    
    // Touching to change the threshold value, if we're thresholding
    //Selecting time interval and thresholding are mutualy exclusive
    else if (touches.size() == 1)
    {
        
        
        
    }
    
}



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



@end
