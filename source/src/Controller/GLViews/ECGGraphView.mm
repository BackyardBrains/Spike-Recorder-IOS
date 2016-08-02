//
//  ECGGraphView.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 9/11/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "ECGGraphView.h"
#import "BBAudioManager.h"

#define HANDLE_RADIUS 20
#define HIDE_HANDLES_AFTER_SECONDS 4.0

@implementation ECGGraphView

//
// Called by super on initWithFrame. It will start animation.
//
- (void)setup
{
    frameCount = 0;
    [self enableMultiTouch:YES];
    firstDrawAfterChannelChange = YES;
    [super setup];//this calls [self startAnimation]

    // Setup the camera
	mCam.lookAt( Vec3f(0.0f, 0.0f, 40.0f), Vec3f::zero() );
    
    [self enableAntiAliasing:NO];
    
    // Make sure that we can autorotate 'n what not.
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    // Set up our font, which we'll use to display the unit scales
    heartFont = Font("Helvetica", 32);
    scaleFont =  Font("Helvetica", 18) ;
    heartRateFont = gl::TextureFont::create( heartFont );
    mScaleFont = gl::TextureFont::create( scaleFont );
    foundBeat = NO;
    lastUserInteraction = [[NSDate date] timeIntervalSince1970];
    handlesShouldBeVisible = NO;
    offsetPositionOfHandle = 0.0f;
    

    int frameCount;//counts frames, used to fix white lable bug
   // autorangeActive = YES;
   // autorangeTimer = [NSTimer scheduledTimerWithTimeInterval:2.5 target:self selector:@selector(stopAutorange) userInfo:nil repeats:NO];
}

-(void) stopAutorange
{

    [self autorangeSelectedChannel];
    
    heartRateFont = nil;
    mScaleFont = nil;
    heartRateFont = gl::TextureFont::create( Font("Helvetica", 32) );
    mScaleFont = gl::TextureFont::create( Font("Helvetica", 18) );

    if(autorangeTimer!=nil)
    {
        autorangeActive = NO;
        [autorangeTimer invalidate];
        autorangeTimer = nil;
    }
    
}

//
// Setup all parameters of view
//
-(void) setupWithBaseFreq:(float) inSamplingRate
{

    [self stopAnimation];
    
    firstDrawAfterChannelChange = YES;
    frameCount = 0;
    samplingRate = inSamplingRate;
    [[BBAudioManager bbAudioManager] setEcgThreshold:0.0f];
    // Setup display vector
    NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    numSamplesMax = [[defaults valueForKey:@"numSamplesMaxNew"] floatValue];
    numSamplesMin  = (int) (0.1*samplingRate);
    numSamplesVisible = (float)(int) (numSamplesMax + numSamplesMin)/2;
    
    numVoltsMin = [[defaults valueForKey:@"numVoltsMin"] floatValue];
    numVoltsMax = [[defaults valueForKey:@"numVoltsMaxUpdate1"] floatValue];
    numVoltsVisible = numVoltsMax*0.2f;
    
    
    //Make x coordinates for signal
    displayVector = PolyLine2f();

    // float offset = ((float)numberOfSamplesMax)/samplingRate;
    float oneStep = 1.0f/samplingRate;
    float maxTime = numSamplesMax * oneStep;
    for (float i=0; i < numSamplesMax; ++i)
    {
        float x = i *oneStep - maxTime;
        displayVector.push_back(Vec2f(x, 0.0f));
    }
    displayVector.setClosed(false);
    
    [[BBAudioManager bbAudioManager] setEcgThreshold:numVoltsVisible*0.3];
    
    [self startAnimation];
}


-(void) autorangeSelectedChannel
{
    numVoltsVisible= [[BBAudioManager bbAudioManager] currMax]*1.3;
    [[BBAudioManager bbAudioManager] setEcgThreshold:numVoltsVisible*0.47];
}

-(void) calculateScale
{
    scaleXY = [self screenToWorld:Vec2f(1.0f,1.0f)];
    Vec2f scaleXYZero = [self screenToWorld:Vec2f(0.0f,0.0f)];
    scaleXY.x = fabsf(scaleXY.x - scaleXYZero.x);
    scaleXY.y = fabsf(scaleXY.y - scaleXYZero.y);
}


//
// Draw graph
//
- (void)draw {
    
        [[BBAudioManager bbAudioManager] fetchAudioForSelectedChannel:(float *)&(displayVector.getPoints()[0])+1 numFrames:numSamplesMax stride:2];
    
        currentUserInteractionTime = [[NSDate date] timeIntervalSince1970];
        handlesShouldBeVisible = (currentUserInteractionTime-lastUserInteraction)<HIDE_HANDLES_AFTER_SECONDS;
    
    
        if(firstDrawAfterChannelChange)
        {

            
            //this is fix for bug. Draw text starts to paint background of text
            //to the same color as text if we don't make new instance here
            //TODO: find a reason for this
            if(frameCount>6 )
            {
                firstDrawAfterChannelChange = NO;
            }
            [self autorangeSelectedChannel];
            
            heartRateFont = nil;
            mScaleFont = nil;
            heartRateFont = gl::TextureFont::create( Font("Helvetica", 32) );
            mScaleFont = gl::TextureFont::create( Font("Helvetica", 18) );
            
        }
    
    
   /* if(firstDrawAfterChannelChange )
    {
        //frameCount++;
        //this is fix for bug. Draw text starts to paint background of text
        //to the same color as text if we don't make new instance here
        //TODO: find a reason for this
        // mScaleFont = nil;
        if(frameCount>4 && !autorangeActive)
        {
            firstDrawAfterChannelChange = NO;
        }
        if((frameCount %2)==1)
        {
            heartRateFont = nil;
            mScaleFont = nil;
            heartRateFont = gl::TextureFont::create( heartFont );
        
            mScaleFont = gl::TextureFont::create( scaleFont );
        }
    }*/
    
    
    

    
    
        if(foundBeat != [[BBAudioManager bbAudioManager] heartBeatPresent])
        {
            foundBeat = [[BBAudioManager bbAudioManager] heartBeatPresent];
            [self.masterDelegate changeHeartActive:foundBeat];
        }
        // this pair of lines is the standard way to clear the screen in OpenGL
        gl::clear( Color( 0.0f, 0.0f, 0.0f ), true );
        glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
        
        [self elasticZoomEfect];
        // Look at it right
        float leftBoundary = -numSamplesVisible*(1.0f/samplingRate);
        mCam.setOrtho(-numSamplesVisible*(1.0f/samplingRate), 0, -numVoltsVisible, numVoltsVisible, 1, 100);
        gl::setMatrices( mCam );
        
        [self calculateScale];
    
        
        glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
        glLineWidth(1.0f);
        gl::draw(displayVector);
        glLineWidth(4.0f);
        glColor4f(1.0f, 0.0f, 0.0f, 1.0f);
        //gl::drawLine(Vec2f(-numSamplesVisible*(1.0f/samplingRate), [[BBAudioManager bbAudioManager] movingAverage]*2.3), Vec2f(0.0f, [[BBAudioManager bbAudioManager] movingAverage]*2.3));
    
       //gl::drawLine(Vec2f(-0.01, 0.0f), Vec2f(-0.01, 1.0f));
    
    
        // Draw X scale ---------------
    
        float lineY = -numVoltsVisible + 100.0f*scaleXY.y;
        float halfSizeOfScale = leftBoundary/4.0f;
    
        Vec2f leftPoint = Vec2f(leftBoundary*0.5+halfSizeOfScale, lineY);
        Vec2f rightPoint = Vec2f(leftBoundary*0.5-halfSizeOfScale, lineY);
        glColor4f(0.8, 0.8, 0.8, 1.0);
        glLineWidth(1.0f);
        gl::drawLine(leftPoint, rightPoint);
    
        [self drawThreshold];
    
    
        //=================== Draw string ====================================
        gl::disableDepthRead();
        gl::setMatricesWindow( Vec2i(self.frame.size.width, self.frame.size.height) );
        gl::enableAlphaBlending();


    
        //Draw heart bit rate text
    
        std::stringstream rateString;
    
        Vec2f xScaleTextSize;
        Vec2f xScaleTextPosition = Vec2f(0.,0.);
        glLineWidth(2.0f);

        rateString << fixed << (int) [[BBAudioManager bbAudioManager] heartRate] ;
        xScaleTextSize = heartRateFont->measureString(rateString.str());
        xScaleTextPosition.x = 56;
        xScaleTextPosition.y =43;
        if(foundBeat)
        {

            glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
            heartRateFont->drawString(rateString.str(), xScaleTextPosition);
        }
    
    
        //Draw X scale text
    
        float xScale = -1000*leftBoundary/2.0f;
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
        xScaleTextSize = mScaleFont->measureString(xStringStream.str());
        xScaleTextPosition = Vec2f(0.,0.);
        xScaleTextPosition.x = (self.frame.size.width - xScaleTextSize.x)/2.0;
        xScaleTextPosition.y =self.frame.size.height - 18;

        glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
        mScaleFont->drawString(xStringStream.str(), xScaleTextPosition);
    
}



-(void) drawThreshold
{
   
        glColor4f(1.0, 0.0, 0.0, 1.0);
        glLineWidth(1.0f);
        float leftEdge = -numSamplesVisible*(1.0f/samplingRate);
        // Draw a line from left to right at the voltage threshold value.
        float threshval = [[BBAudioManager bbAudioManager] ecgThreshold];
        
        float centerOfCircleX = -20*scaleXY.x;
        float radiusXAxis = HANDLE_RADIUS*scaleXY.x;
        float radiusYAxis = HANDLE_RADIUS*scaleXY.y;
    
        BOOL makeThrLineThin = NO;
        //hide/show animation of handles
        if(handlesShouldBeVisible)
        {
            offsetPositionOfHandle+=radiusXAxis/3.0;
            if(offsetPositionOfHandle>0.0)
            {
                offsetPositionOfHandle = 0.0;
            }
        }
        else
        {
            offsetPositionOfHandle-=radiusXAxis/5.0;
            if(offsetPositionOfHandle<-2.6*radiusXAxis)
            {
                offsetPositionOfHandle = -2.6*radiusXAxis;
                makeThrLineThin = YES;
            }
        }
        
        centerOfCircleX -= offsetPositionOfHandle;
    
    
        

        
        //draw all handles
        
        gl::drawSolidEllipse( Vec2f(centerOfCircleX, threshval), radiusXAxis, radiusYAxis, 100 );
        gl::drawSolidTriangle(
                              Vec2f(centerOfCircleX-0.35*radiusXAxis, threshval+radiusYAxis*0.97),
                              Vec2f(centerOfCircleX-1.6*radiusXAxis, threshval),
                              Vec2f(centerOfCircleX-0.35*radiusXAxis, threshval-radiusYAxis*0.97)
                              );
        if(makeThrLineThin)
        {
            glLineWidth(1.0f);
            glColor4f(0.8, 0.0, 0.0, 1.0);
        }
        else
        {
            glLineWidth(2.0f);
        }
        float linePart = radiusXAxis*0.7;
        for(float pos=leftEdge;pos<-linePart; pos+=linePart+linePart)
        {
            gl::drawLine(Vec2f(pos, threshval), Vec2f(pos+linePart, threshval));
        }
        
        glLineWidth(1.0f);
  
}

- (void)dealloc
{
    mScaleFont = nil;
    heartRateFont = nil;
    [super dealloc];
}


//====================================== TOUCH ===============================
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


-(void) elasticZoomEfect
{
    if ([self getActiveTouches].size() != 2)
    {
        // Make sure that we don't go out of bounds
        if (numSamplesVisible < numSamplesMin)
        {
            numSamplesVisible += 0.6*((numSamplesMin+1) - numSamplesVisible);
        }
        if(numSamplesVisible>numSamplesMax)
        {
            numSamplesVisible += 0.6*((numSamplesMax-1) - numSamplesVisible);
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
        float oldNumVoltsVisible = numVoltsVisible;
        
        float deltax = fabs(touchDistanceDelta.x-1.0f);
        float deltay = fabs(touchDistanceDelta.y-1.0f);
        // NSLog(@"Touch X: %f", deltax/deltay);
        
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
        numVoltsVisible /= (touchDistanceDelta.y - 1) + 1;
        
       
        if (numVoltsVisible < 0.001)
        {
            touchDistanceDelta.y = 1.0f;
            numVoltsVisible = oldNumVoltsVisible;
        }
        if(numVoltsVisible>numVoltsMax)
        {
            touchDistanceDelta.y = 1.0f;
            numVoltsVisible = oldNumVoltsVisible;
        }
        
    }
    else if (touches.size() == 1)
    {
        //last time we tap screen with one finger. We use this to hide hanles
        lastUserInteraction = [[NSDate date] timeIntervalSince1970];
        
        Vec2f touchPos = touches[0].getPos();
        // Convert into GL coordinate
        Vec2f glWorldTouchPos = [self screenToWorld:touchPos];

        float currentThreshold = [[BBAudioManager bbAudioManager] ecgThreshold];
        
        float intersectionDistanceX = 16000*scaleXY.x*scaleXY.x;
        float intersectionDistanceY = 18000*scaleXY.y*scaleXY.y;
        
        //check first if user grabbed selected channel
        if((glWorldTouchPos.y - currentThreshold)*(glWorldTouchPos.y - currentThreshold) < intersectionDistanceY && (glWorldTouchPos.x * glWorldTouchPos.x) <intersectionDistanceX)
        {
            [[BBAudioManager bbAudioManager] setEcgThreshold:glWorldTouchPos.y];
        }
        
    }
}



#pragma mark - helper functions
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
