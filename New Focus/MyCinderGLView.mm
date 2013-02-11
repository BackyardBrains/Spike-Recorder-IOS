//
//  MyCinderGLView.mm
//  CCGLTouchBasic example
//
//  More info on the CCGLTouch project >> http://www.smallab.org/code/ccgl-touch/
//  License & disclaimer >> see license.txt file included in the distribution package
//

#import "MyCinderGLView.h"

@interface MyCinderGLView ()
{
    BBAudioManager *audioManager;
    float destNumSecondsVisible; // used for short animations of scaling the plot
    float touchStartTime;
}

- (Vec2f)calculateTouchDistanceChange:(std::vector<ci::app::TouchEvent::Touch>)touches;
- (void)fillDisplayVector;
- (void)drawScaleText;
- (void)drawGrid;

@end

@implementation MyCinderGLView

@synthesize stimulating;
@synthesize recording;

- (void)renderFont
{

}

- (void)setup
{
    [super setup];
    
    // Setup the camera
	mCam.lookAt( Vec3f(0.0f, 0.0f, 40.0f), Vec3f::zero() );
	
    // Initialize parameters
    mCubeSize = 10;
    numSecondsMax = 6;
    
    numSecondsMin = 0.02;
    numSecondsVisible = 0.1;
    
    numVoltsMin = 0.05;
    numVoltsMax = 1.6;
    numVoltsVisible = numVoltsMax;
    
    // Setup multitouch
    [self enableMultiTouch:YES];

    // Setup audio
    audioManager = [BBAudioManager bbAudioManager];

    // Setup display vector
    displayVector = PolyLine2f();
    
    float numPoints = numSecondsMax * audioManager.samplingRate;
    for (float i=0; i < numPoints; ++i)
    {
        float x = (i / audioManager.samplingRate) - numSecondsMax;
        displayVector.push_back(Vec2f(x, 0.0f));
    }
    displayVector.setClosed(false);
    
    // Make sure that we can autorotate 'n what not.
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    // Set up our font, which we'll use to display the unit scales

    mScaleFont = gl::TextureFont::create( Font("Helvetica", 18) );

}

- (void)draw {
    
    // this pair of lines is the standard way to clear the screen in OpenGL
	gl::clear( Color( 0.0f, 0.0f, 0.0f ), true );
	glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    
    
    // Look at it right
    mCam.setOrtho(-numSecondsVisible, -numSecondsMin, -numVoltsVisible/2.0f, numVoltsVisible/2.0f, 1, 100);;
    gl::setMatrices( mCam );
    
    // Set the line color and width
    glColor4f(0.0f, 1.0f, 0.0f, 1.0f);
    glLineWidth(1.0f);

    // Put the audio on the screen
    [self fillDisplayVector];
    gl::draw(displayVector);

    
    // Draw a threshold line, if we're thresholding
    if ([[BBAudioManager bbAudioManager] thresholding]) {
        glColor4f(1.0, 0.0, 0.0, 1.0);
        glLineWidth(1.0f);
        
        // Draw a line from left to right at the voltage threshold value.
        float threshval = [[BBAudioManager bbAudioManager] threshold];
        gl::drawLine(Vec2f(-numSecondsVisible, threshval), Vec2f(-numSecondsMin, threshval));
        
    }
            
    
    // Put a little grid on the screen.
    [self drawGrid];
    
    // Draw some text on that screen
    [self drawScaleText];
    
}

- (void)drawScaleText
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
    
    float xScale = xMiddle.x - xFarLeft.x;
    float yScale = yScaleWorldPosition.y;
    
    // Figure out what we want to say
    std::ostringstream yStringStream;
    yStringStream.precision(3);
    yStringStream << yScale << " mV";
    std::ostringstream xStringStream;
    xStringStream.precision(3);
    xStringStream << xScale << " sec";
    
    // Now that we have the string, calculate the position of the x-scale text
    // (we'll be horizontally centering by hand)
    Vec2f xScaleTextSize = mScaleFont->measureString(xStringStream.str());
    Vec2f xScaleTextPosition = Vec2f(0.,0.);
    xScaleTextPosition.x = (self.frame.size.width - xScaleTextSize.x)/2.0;
    xScaleTextPosition.y =0.95*self.frame.size.height + (mScaleFont->getAscent() / 2.0f);
    
	gl::color( ColorA( 1.0, 1.0f, 1.0f, 1.0f ) );
    
    // Draw the y-axis scale text
    mScaleFont->drawString(yStringStream.str(), yScaleTextPosition);
    
    // Draw the x-axis scale text
    mScaleFont->drawString(xStringStream.str(), xScaleTextPosition);
    
    gl::enableDepthRead();
    
}


- (void)drawGrid
{
    
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


- (void)fillDisplayVector
{
    
    // We'll be checking if we have to limit the amount of points we display on the screen
    // (e.g., the user is allowed to pinch beyond the maximum allowed range, but we
    // just display what's available, and then stretch it back to the true limit)
    
    // See if we're asking for TOO MANY points
    int numPoints, offset;
    if (numSecondsVisible > numSecondsMax) {
        numPoints = numSecondsMax * audioManager.samplingRate;
        offset = 0;
        
        if ([self getActiveTouches].size() != 2)
            numSecondsVisible += 0.6 * (numSecondsMax - numSecondsVisible);
    }
    
    // See if we're asking for TOO FEW points
    else if (numSecondsVisible < numSecondsMin)
    {
        numPoints = numSecondsMin * audioManager.samplingRate;
        offset = 0;
        
        if ([self getActiveTouches].size() != 2)
            numSecondsVisible += 0.6 * (numSecondsMin*2.0 - numSecondsVisible);
        
    }
    
    // If we haven't set off any of the alarms above,
    // then we're asking for a normal range of points.
    else {
        numPoints = numSecondsVisible * audioManager.samplingRate;
        offset = numSecondsMax * audioManager.samplingRate - numPoints;
        if ([[BBAudioManager bbAudioManager] thresholding]) {
            offset -= (numSecondsMin * audioManager.samplingRate)/2.0f;
        }
    }
    
    // Aight, now that we've got our ranges correct, let's ask for the audio.
//    NSLog(@"Drawing %d/%d points, offset: %d", numPoints, (int)(numSecondsMax * audioManager.samplingRate), offset);
    [audioManager fetchAudio:(float *)&(displayVector.getPoints()[offset])+1 numFrames:numPoints whichChannel:0 stride:2];

}


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
    if ( isnan(deltaX) )
        deltaX = 1.0f;

    if ( isnan(deltaY) )
        deltaY = 1.0f;
    
    return Vec2f(deltaX, deltaY);
}

- (void)updateActiveTouches
{
    [super updateActiveTouches];

    std::vector<ci::app::TouchEvent::Touch> touches = [self getActiveTouches];
    
    // Pinching to zoom the display
    if (touches.size() == 2)
    {
        Vec2f touchDistanceDelta = [self calculateTouchDistanceChange:touches];
        numSecondsVisible /= (touchDistanceDelta.x - 1) + 1;
        numVoltsVisible /= (touchDistanceDelta.y - 1) + 1;
        
        // If we are thresholding,
        // we will not allow the springy x-axis effect to occur
        // (why? we always want the x-axis to be centered on the threshold value)
        if ([[BBAudioManager bbAudioManager] thresholding]) {
            // slightly tigher bounds on the thresholding view (don't need to see whole second and a half in this view)
            float thisNumSecondsMax = 1.5;
            numSecondsVisible = (numSecondsVisible < thisNumSecondsMax - 0.25) ? numSecondsVisible : (thisNumSecondsMax-0.25);
            numSecondsVisible = (numSecondsVisible > numSecondsMin) ? numSecondsVisible : numSecondsMin;
        }
        
    }
    
    // Touching to change the threshold value, if we're thresholding
    else if (touches.size() == 1)
    {
        
        if ([[BBAudioManager bbAudioManager] thresholding]) {
            Vec2f touchPos = touches[0].getPos();
            float currentThreshold = [[BBAudioManager bbAudioManager] threshold];
            
            // Convert into voltage coordinates, and then into audio coordinates
            Vec2f worldTouchPos = [self screenToWorld:touchPos];
            Vec2f screenThresholdPos = [self worldToScreen:Vec2f(0.0f, currentThreshold)];
            
            float distance = abs(touchPos.y - screenThresholdPos.y);
            if (distance < 20) // set via experimentation
            {
                [[BBAudioManager bbAudioManager] setThreshold:worldTouchPos.y];
            }

        }
        
    }

}







- (void)setCubeSize:(float)size
{
    numSecondsVisible = size;
}


#pragma mark - Utility
- (Vec2f)screenToWorld:(Vec2f)point
{

    float windowHeight = self.frame.size.height;
    float windowWidth = self.frame.size.width;
    

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


// UNTESTED THUS FAR
- (Vec2f)worldToScreen:(Vec2f)point
{

    float windowHeight = self.frame.size.height;
    float windowWidth = self.frame.size.width;

    
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
