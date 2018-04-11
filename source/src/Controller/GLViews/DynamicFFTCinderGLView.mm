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
#define SIZE_OF_RAW 0.4f

@implementation DynamicFFTCinderGLView

//
// Called by super on initWithFrame. It will start animation.
//
- (void)setup
{
    lengthOfFFTData = 128;//1024;
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
    
    currentTimeFont = Font("Helvetica", 13);//26/retinaScaling);
    currentTimeTextureFont = gl::TextureFont::create( currentTimeFont );
    
    retinaCorrection = 2.0f;
   if([[UIScreen mainScreen] respondsToSelector:@selector(scale)] )
    {//if it is retina correct scale
        retinaCorrection = 1/((float)[[UIScreen mainScreen] scale]);
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
   // float tempOverload = 11825.0f/tempNumberOfPix;//Hack for older phones that have old graphic cards
    int newFreq = lengthOfFFTData;//*tempOverload;
    
    
    baseFreq = inBaseFreq;
    //we put here -1 because FFT buffer has one more graph than we need.
    //We made this because we had grapical gliches because calculating of FFT and drawing are asinc.
    //Now that FT has one more graph it can write new graph in additional element of buffer that is never used for display.
    baseTime = inMaxTime/((float) inNumOfGraphs-4);
    
    maxFreq = baseFreq*( lengthOfFFTData>newFreq?newFreq:lengthOfFFTData);
    initialMaxFrequency = maxFreq;
    maxTime = inMaxTime;
    
    currentMaxFreq = maxFreq;
    currentMaxTime = maxTime;
    
    [self calculateScale];
    
    
    // Setup display vector
    
    NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    numberOfSamplesMax = [[defaults valueForKey:@"numSamplesMaxNew"] floatValue];
    
    //Make x coordinates for raw signal
    rawSignal = PolyLine2f();
    samplingRate = [[BBAudioManager bbAudioManager] sourceSamplingRate];
    // float offset = ((float)numberOfSamplesMax)/samplingRate;
    float oneStep = maxTime/((float)numberOfSamplesMax);
    for (float i=0; i < numberOfSamplesMax; ++i)
    {
        float x = i *oneStep - maxTime;
        rawSignal.push_back(Vec2f(x, 0.0f));
    }
    rawSignal.setClosed(false);
    rawSignalTimeVisible = 6.0f;
    rawSignalVoltsVisible = 10.0f;
    
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


- (void)dealloc
{
    mScaleFont = nil;
    [super dealloc];
}

//
// Draw graph
//
- (void)draw {

    float ** graphBuffer = [[BBAudioManager bbAudioManager] getDynamicFFTResult];
    [[BBAudioManager bbAudioManager] fetchAudioForSelectedChannel:(float *)&(rawSignal.getPoints()[0])+1 numFrames:numberOfSamplesMax stride:2];

    if(graphBuffer)
    {
        if(firstDrawAfterChannelChange)
        {
            //this is fix for bug. Draw text starts to paint background of text
            //to the same color as text if we don't make new instance here
            //TODO: find a reason for this
            firstDrawAfterChannelChange = NO;
            mScaleFont = nil;
           mScaleFont = gl::TextureFont::create( Font("Helvetica", 12) );
            currentTimeTextureFont = nil;
           currentTimeTextureFont = gl::TextureFont::create( currentTimeFont );
           
        }

        // this pair of lines is the standard way to clear the screen in OpenGL
        gl::clear( Color( 0.0f, 0.0f, 0.0f ), true );
        glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
        

        // Look at it right
        mCam.setOrtho(-currentMaxTime, 0, 0, currentMaxFreq*(1.0f+SIZE_OF_RAW), 1, 100);
        gl::setMatrices( mCam );

        [self calculateScale];
        [self calculateAxisIntervals];

        offsetX = X_AXIS_OFFSET* scaleXY.x/(2*retinaCorrection);
        offsetY = Y_AXIS_OFFSET* scaleXY.y/(2*retinaCorrection);
        
        
        //--------------------------- Draw raw signal waveform ------------------------------------------
        
        float offsetOfRawSignal = currentMaxFreq + 0.5f*(currentMaxFreq*(1.0f+SIZE_OF_RAW)-currentMaxFreq);
        float amplitudeZoom =rawSignalVoltsVisible *currentMaxFreq/initialMaxFrequency;

        vDSP_vsmsa ((float *)&(rawSignal.getPoints()[0])+1,
                    2,
                    &amplitudeZoom,
                    &offsetOfRawSignal,
                    (float *)&(rawSignal.getPoints()[0])+1,
                    2,
                    numberOfSamplesMax
                    );

        
        glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
        glLineWidth(1.0f);
        gl::draw(rawSignal);

        glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
        glLineWidth(10.0f);

        
        // ------------------------------ Make Spectrum image -------------------------------------------
        
        float normPower;
        int freqIndex;
        float redC = 0;
        float greenC = 0;
        float blueC=0;
        float endOfTime = -currentMaxTime+offsetX;
        int indexOfGraphs;

        int widthS =abs(endOfTime/baseTime)-4;
        int heightS = abs((currentMaxFreq-offsetY)/baseFreq);
        
        Surface mySurface = Surface(widthS, heightS, false);
        Surface::Iter mySurfaceIter( mySurface.getIter() );
        
        int indexOfGraphsPos = ([[BBAudioManager bbAudioManager] indexOfFFTGraphBuffer]+lengthOfFFTBuffer-widthS-1)%lengthOfFFTBuffer;
        freqIndex = 0;
        while( mySurfaceIter.line() )
        {
            indexOfGraphs = indexOfGraphsPos;
            while( mySurfaceIter.pixel() )
            {
                indexOfGraphs++;
                if(indexOfGraphs==lengthOfFFTBuffer)
                {
                    indexOfGraphs = 0;
                }
                
                normPower = graphBuffer[indexOfGraphs][heightS-freqIndex-1];
                redC = red(normPower);
                greenC = green(normPower);
                blueC = blue(normPower);
                
                mySurfaceIter.g() = greenC*255; // for brevity I have omitted the calcs for newR, newG, newB
                mySurfaceIter.r() = redC*255;
                mySurfaceIter.b() = blueC*255;
                
            }
            freqIndex++;
        }
        
        //------------------------- Draw Spectrum image ------------------------------------------------

        gl::disableDepthRead();
        
        
        gl::setMatricesWindow( Vec2i(self.frame.size.width, self.frame.size.height) );
        gl::enableAlphaBlending();
    
        
        
        // and in your App's draw()
        gl::Texture myTexture = gl::Texture( mySurface );
        myTexture.bind();
        float yTop = self.frame.size.height - retinaCorrection*(currentMaxFreq/scaleXY.y);
        float yBottom = self.frame.size.height;
        float xLeft = 0.0f;
        float xRight = self.frame.size.width;
        
        gl::draw(myTexture,Rectf(xLeft,yTop,xRight,yBottom));
        gl::enableDepthRead();
        
        gl::setMatrices( mCam );
        //----------------------------- Marks for X axis - Time --------------------------------------------
        
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

        
        //----------------------------- Mark for Y axis frequency --------------------------------------------
        
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
            if(markPos>currentMaxFreq)
            {
                break;
            }
        }
        

        //------------------------------------- Draw scale text -----------------------------------------------
        
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
        
        float topEdgeOfSpectrogram = self.frame.size.height - retinaCorrection*(currentMaxFreq/scaleXY.y);
        
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
            xScaleTextPosition.y =15+ topEdgeOfSpectrogram;
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
        hzString << fixed << "Time [S]";
        xScaleTextSize = mScaleFont->measureString(hzString.str());
        
        xScaleTextPosition.x = self.frame.size.width - xScaleTextSize.x*1.5 ;
        
        xScaleTextPosition.y =35+topEdgeOfSpectrogram;
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
            if(xScaleTextPosition.y>30+topEdgeOfSpectrogram)
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
        
        
        [self drawCurrentTime];

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

-(void) drawCurrentTime
{
    //show current time label if we are in playback mode
    if ([[self masterDelegate] respondsToSelector:@selector(areWeInFileMode)])
    {
        if([[self masterDelegate] areWeInFileMode])
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
            currentTimeTextPosition.y = self.frame.size.height-10 - retinaCorrection*(currentMaxFreq/scaleXY.y) - (currentTimeTextureFont->getAscent() / 2.0f);
            currentTimeTextureFont->drawString(currentTimeStringStream.str(), currentTimeTextPosition);
            gl::enableDepthRead();
        }
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
    
    
    int pinchType = [self determinePinchType:touches];
    switch(pinchType)
    {
        case 1: //vertical pinch
            deltaX = 1.0f;
            break;
        case 2: //horizontal pinch
            deltaY = 1.0f;
            break;
        default: //diagonal pinch, we don't react on that
            deltaX = 1.0f;
            deltaY = 1.0f;
            break;
    }
    
    
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
        
        // Convert into GL coordinate
        Vec2f position1 = [self screenToWorld:touches[0].getPos()];
        Vec2f position2 = [self screenToWorld:touches[1].getPos()];
        
        
        
        //FFT graph zoom
        
        Vec2f touchDistanceDelta = [self calculateTouchDistanceChange:touches];
        
        if(position1.y<currentMaxFreq && position2.y<currentMaxFreq)
        {
            
            float oldMaxFreq = currentMaxFreq;
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
        }
        
        
        //raw signal zoom
        if(position1.y>currentMaxFreq && position2.y>currentMaxFreq)
        {
            rawSignalVoltsVisible *= (sqrtf(touchDistanceDelta.y) - 1) + 1;
        }
        
        currentMaxTime /= (sqrtf(touchDistanceDelta.x) - 1) + 1;
        
        
        if (currentMaxTime < 1.1 )
        {
            currentMaxTime = 1.1;
        }
        
        if(currentMaxTime>maxTime)
        {
            currentMaxTime = maxTime;
        }

    }
    else if (touches.size() == 1)
    {
        //inform main controller tat view has been touched
        [[self masterDelegate] glViewTouched];
        
        
        //one finger seek
        if(![[BBAudioManager bbAudioManager] playing])
        {
            float windowWidth = self.frame.size.width;
           // if([[UIScreen mainScreen] respondsToSelector:@selector(scale)] )
           // {
           //     windowWidth *= [[UIScreen mainScreen] scale];
           // }
            float diffPix = touches[0].getPos().x - touches[0].getPrevPos().x;
            float timeDiff = (-diffPix/windowWidth)*abs(currentMaxTime);
            [[BBAudioManager bbAudioManager] setSeeking:YES];
            [[BBAudioManager bbAudioManager] setSeekTime:[[BBAudioManager bbAudioManager] currentFileTime] + timeDiff ];
        }
    }
    
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


#pragma mark - Utility

-(void) autorangeSelectedChannel
{
    rawSignalVoltsVisible = 1/(0.3*[[BBAudioManager bbAudioManager] currMax]);
}


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
    if([[UIScreen mainScreen] respondsToSelector:@selector(scale)] )
    {
        float screenScale = [[UIScreen mainScreen] scale];
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
        float screenScale = [[UIScreen mainScreen] scale];
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


@end
