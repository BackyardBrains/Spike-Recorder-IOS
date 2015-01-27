//
//  SpikesCinderView.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/10/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "SpikesCinderView.h"
#import "BBSpike.h"

@interface SpikesCinderView ()
{
    BBAnalysisManager *analysisManager;
    float destNumSecondsVisible; // used for short animations of scaling the plot
    float touchStartTime;
    BOOL weAreDrawingSelection;
}

- (Vec2f)calculateTouchDistanceChange:(std::vector<ci::app::TouchEvent::Touch>)touches;
- (void)fillDisplayVector;
- (void)drawGrid;

@end


@implementation SpikesCinderView


- (void)renderFont
{
    
}

- (void)setup
{
    [super setup];
    
    // Setup the camera
	mCam.lookAt( Vec3f(0.0f, 0.0f, 40.0f), Vec3f::zero() );
	
    [self loadSettings];

    
    // Setup multitouch
    [self enableMultiTouch:YES];
    
    // Setup manager
    analysisManager = [BBAnalysisManager bbAnalysisManager];
    
    //numSecondsMax = (numSecondsMax/[[[BBAnalysisManager bbAnalysisManager] fileToAnalyze] numberOfChannels])*1.5;
    
    // Setup display vector
    displayVector = PolyLine2f();
    
    float numPoints = numSecondsMax * analysisManager.fileToAnalyze.samplingrate;
    for (float i=0; i < numPoints; ++i)
    {
        float x = (i / analysisManager.fileToAnalyze.samplingrate) - numSecondsMax;
        displayVector.push_back(Vec2f(x, 0.0f));
    }
    displayVector.setClosed(false);
    
    // Make sure that we can autorotate 'n what not.
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    // Set up our font, which we'll use to display the unit scales
    mScaleFont = gl::TextureFont::create( Font("Helvetica", 18) );
    
    [self getAllSpikes];
}

- (void)dealloc
{
    mScaleFont = nil;
    [super dealloc];
}

-(void) channelChanged
{
    [self getAllSpikes];
}

//Push all spikes in PolyLine2f object
-(void) getAllSpikes
{
    allSpikes = PolyLine2f();
    BBSpike * tempSpike;
    if([[analysisManager allSpikes] count]==0)
    {
        return;
    }
    for (int i=0; i < [[analysisManager allSpikes] count]; ++i)
    {
        tempSpike = (BBSpike *)[[analysisManager allSpikes] objectAtIndex:i];
        allSpikes.push_back(Vec2f([tempSpike time] , [tempSpike value]));
    }
}

- (void)loadSettings
{
    
    NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
 
    numSecondsMax = [[defaults valueForKey:@"numSecondsMax"] floatValue];
    numSecondsMax = (numSecondsMax/[[[BBAnalysisManager bbAnalysisManager] fileToAnalyze] numberOfChannels]*1.5);
    numSecondsMin = [[defaults valueForKey:@"numSecondsMin"] floatValue];
    numSecondsVisible = [[defaults valueForKey:@"numSecondsVisible"] floatValue];
    numVoltsMin = [[defaults valueForKey:@"numVoltsMin"] floatValue];
    numVoltsMax = [[defaults valueForKey:@"numVoltsMax"] floatValue];
    numVoltsVisible = [[defaults valueForKey:@"numVoltsVisible"] floatValue];

    
}

- (void)saveSettings
{
    NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
   
    //[defaults setValue:[NSNumber numberWithFloat:numSecondsMax] forKey:@"numSecondsMax"];
    [defaults setValue:[NSNumber numberWithFloat:numSecondsMin] forKey:@"numSecondsMin"];
    [defaults setValue:[NSNumber numberWithFloat:numSecondsVisible] forKey:@"numSecondsVisible"];
    [defaults setValue:[NSNumber numberWithFloat:numVoltsMin] forKey:@"numVoltsMin"];
    [defaults setValue:[NSNumber numberWithFloat:numVoltsMax] forKey:@"numVoltsMax"];
    [defaults setValue:[NSNumber numberWithFloat:numVoltsVisible] forKey:@"numVoltsVisible"];

    
    [defaults synchronize];
}

- (void)draw {
    
    // this pair of lines is the standard way to clear the screen in OpenGL
	gl::clear( Color( 0.0f, 0.0f, 0.0f ), true );
	glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    
    
    // Look at it right
    mCam.setOrtho(-numSecondsVisible, -numSecondsMin, -numVoltsVisible/2.0f, numVoltsVisible/2.0f, 1, 100);;
    gl::setMatrices( mCam );
    
    
 
    //Calculate ref size values in Cinder world
   /* Vec2f refSizeS = [self worldToScreen:Vec2f(-numSecondsMin,0.0)];
    Vec2f refSizeW = [self screenToWorld:Vec2f(refSizeS.x-10,refSizeS.y+10)];
    float tenPixX =refSizeW.x+numSecondsMin;
    float tenPixY =refSizeW.y;*/
    
    Vec2f scaleXY = [self screenToWorld:Vec2f(1.0f,1.0f)];
    Vec2f scaleXYZero = [self screenToWorld:Vec2f(0.0f,0.0f)];
    scaleXY.x = fabsf(scaleXY.x - scaleXYZero.x);
    scaleXY.y = fabsf(scaleXY.y - scaleXYZero.y);
    
    
    
   // gl::drawSolidRect(Rectf(refSize.x,refSize.y,refSize.x-refSize.x, refSize.y+refSize.y));
    // Set the line color and width
    glColor4f(0.4f, 0.4f, 0.4f, 1.0f);
    glLineWidth(2.0f);
    // Put the audio on the screen
    [self fillDisplayVector];
    gl::draw(displayVector);
    
    glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
    glLineWidth(1.0f);
    //Draw spikes
    gl::disableDepthRead();
    BOOL weAreInInterval = NO;
    std::vector<Vec2f>	 spikes = allSpikes.getPoints();
    float sizeOfPointX = 4*scaleXY.x;
    float sizeOfPointY = 4*scaleXY.y;
    float startTimeToDisplay = [[BBAnalysisManager bbAnalysisManager] currentFileTime]-((numSecondsVisible> numSecondsMax)?numSecondsMax:numSecondsVisible);
    float endTimeToDisplay = [[BBAnalysisManager bbAnalysisManager] currentFileTime];
    for(int i=0; i < spikes.size(); i++)
    {
        if(spikes[i].x>startTimeToDisplay && spikes[i].x<endTimeToDisplay)
        {
            weAreInInterval = YES;
            //check if spike is in one of the selected intervals
            if((spikes[i].y<[[BBAnalysisManager bbAnalysisManager] thresholdFirst] && spikes[i].y>[[BBAnalysisManager bbAnalysisManager] thresholdSecond]) || (spikes[i].y>[[BBAnalysisManager bbAnalysisManager] thresholdFirst] && spikes[i].y<[[BBAnalysisManager bbAnalysisManager] thresholdSecond]))
            {
                [self setGLColor:[BYBGLView getSpikeTrainColorWithIndex:[[BBAnalysisManager bbAnalysisManager] currentChannel]+[[BBAnalysisManager bbAnalysisManager] currentSpikeTrain] transparency:1.0f]];
            }
            else
            {
                glColor4f(0.9f, 0.9f, 0.9f, 1.0f); //draw unselected spike
            }
            //draw spike mark
            gl::drawSolidEllipse( Vec2f(spikes[i].x-endTimeToDisplay, spikes[i].y), sizeOfPointX,sizeOfPointY, 100 );
        }
        else if(weAreInInterval)
        {
            break;
        }
    }
        gl::enableDepthRead();

    // Put a little grid on the screen.
    [self drawGrid];
    

    //add handles for threshold lines
    gl::disableDepthRead();
    glColor4f(0.3f, 0.3f, 1.0f, 1.0f);
    float threshval1 = [[BBAnalysisManager bbAnalysisManager] thresholdFirst];
    float threshval2 = [[BBAnalysisManager bbAnalysisManager] thresholdSecond];
    
    

    
    float leftxcenterHandle = -numSecondsMin-20*scaleXY.x;
    float rightxcenterHandle = -numSecondsVisible+20*scaleXY.x;
    float radiusXAxis = 20*scaleXY.x;
    float radiusYAxis = 20*scaleXY.y;
    
   
    [self setGLColor:[BYBGLView getSpikeTrainColorWithIndex:[[BBAnalysisManager bbAnalysisManager] currentSpikeTrain] transparency:1.0f]];
    gl::drawSolidEllipse( Vec2f(leftxcenterHandle, threshval1), radiusXAxis, radiusYAxis, 1000 );
    gl::drawSolidTriangle(
                          Vec2f(leftxcenterHandle-0.35*radiusXAxis, threshval1+radiusYAxis*0.97),
                          Vec2f(leftxcenterHandle-1.6*radiusXAxis, threshval1),
                          Vec2f(leftxcenterHandle-0.35*radiusXAxis, threshval1-radiusYAxis*0.97)
                          );
    
    gl::drawSolidEllipse( Vec2f(rightxcenterHandle, threshval2), radiusXAxis, radiusYAxis, 1000 );
    gl::drawSolidTriangle(
                          Vec2f(rightxcenterHandle+0.35*radiusXAxis, threshval2+radiusYAxis*0.97),
                          Vec2f(rightxcenterHandle+1.6*radiusXAxis, threshval2),
                          Vec2f(rightxcenterHandle+0.35*radiusXAxis, threshval2-radiusYAxis*0.97)
                          );
    
    glLineWidth(2.0f);
    gl::drawLine(Vec2f(-numSecondsVisible, threshval1), Vec2f(-numSecondsMin, threshval1));
    gl::drawLine(Vec2f(-numSecondsVisible, threshval2), Vec2f(-numSecondsMin, threshval2));
    glLineWidth(1.0f);
    
    
    
    
    
   /* glLineWidth(2.0f);
    gl::drawLine(Vec2f(-numSecondsVisible, threshval1), Vec2f(-numSecondsMin, threshval1));
    gl::drawLine(Vec2f(-numSecondsVisible, threshval2), Vec2f(-numSecondsMin, threshval2));
    glLineWidth(1.0f);
    gl::drawSolidRect(Rectf(-numSecondsMin+5*tenPixX,threshval1-2*tenPixY,-numSecondsMin,threshval1+2*tenPixY));
    gl::drawSolidTriangle(Vec2f(-numSecondsMin+5*tenPixX,threshval1-2*tenPixY), Vec2f(-numSecondsMin+5*tenPixX,threshval1+2*tenPixY), Vec2f(-numSecondsMin+7*tenPixX,threshval1));
    
    gl::drawSolidRect(Rectf(-numSecondsVisible-5*tenPixX,threshval2-2*tenPixY,-numSecondsVisible,threshval2+2*tenPixY));
    gl::drawSolidTriangle(Vec2f(-numSecondsVisible-5*tenPixX,threshval2-2*tenPixY), Vec2f(-numSecondsVisible-5*tenPixX,threshval2+2*tenPixY), Vec2f(-numSecondsVisible-7*tenPixX,threshval2));
    gl::enableDepthRead();*/
    
    
    
    // Draw some text on that screen
    [self drawScaleTextAndSelected];
}



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
    
    float xScale = 1000.0*(xMiddle.x - xFarLeft.x);
    float yScale = yScaleWorldPosition.y;
    if([[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale]==2.0)
    {//if it is retina correct scale
        //TODO: This should be tested with calibration voltage source
        xScale *= 2.0f;
        yScale /=2.0f;
    }
    
    
    // Figure out what we want to say
    std::ostringstream yStringStream;
    yStringStream.precision(2);
    yStringStream << fixed << yScale << " mV";
    std::stringstream xStringStream;
    xStringStream.precision(1);
    if (xScale >= 1000) {
        xScale /= 1000.0;
        xStringStream << fixed << xScale << " s";
    }
    else {
        xStringStream << fixed << xScale << " msec";
    }
    
	gl::color( ColorA( 1.0, 1.0f, 1.0f, 1.0f ) );
    
    
    // Draw the y-axis scale text
    
    mScaleFont->drawString(yStringStream.str(), yScaleTextPosition);
    

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


- (void)drawGrid
{
    //draw line for x-axis
    float left, top, right, bottom, near, far;
    mCam.getFrustum(&left, &top, &right, &bottom, &near, &far);
    float height = top - bottom;
    float width = right - left;
    float middleX = (right - left)/2.0f + left;
    //draw line for x-axis if we are not displaying time interval measure
    if (!weAreDrawingSelection) {
        float lineLength = 0.5*width;
        float lineY = height*0.1 + bottom;
        Vec2f leftPoint = Vec2f(middleX - lineLength / 2.0f, lineY);
        Vec2f rightPoint = Vec2f(middleX + lineLength / 2.0f, lineY);
        glColor4f(0.8, 0.8, 0.8, 1.0);
        glLineWidth(1.0f);
        gl::drawLine(leftPoint, rightPoint);
    }
}


- (void)fillDisplayVector
{
    
    // We'll be checking if we have to limit the amount of points we display on the screen
    // (e.g., the user is allowed to pinch beyond the maximum allowed range, but we
    // just display what's available, and then stretch it back to the true limit)
    float samplingRate = analysisManager.fileToAnalyze.samplingrate;
    // See if we're asking for TOO MANY points
    int numPoints, offset;
    if (numSecondsVisible > numSecondsMax) {
        numPoints = numSecondsMax * samplingRate;
        offset = 0;
        
        if ([self getActiveTouches].size() != 2)
            numSecondsVisible += 0.6 * (numSecondsMax - numSecondsVisible);//animation to max seconds
    }
    
    // See if we're asking for TOO FEW points
    else if (numSecondsVisible < numSecondsMin)
    {
        numPoints = numSecondsMin * samplingRate;
        offset = 0;
        
        if ([self getActiveTouches].size() != 2)
            numSecondsVisible += 0.6 * (numSecondsMin*2.0 - numSecondsVisible);//animation to min sec
        
    }
    
    // If we haven't set off any of the alarms above,
    // then we're asking for a normal range of points.
    else {
        numPoints = numSecondsVisible * samplingRate;//visible part
        offset = numSecondsMax * samplingRate - numPoints;//nonvisible part
    }
    
    // Aight, now that we've got our ranges correct, let's ask for the audio.
    //Only fetch visible part (numPoints samples) and put it after offset.
    //Stride is equal to 2 since we have x and y coordinatesand we want to set only y
    [analysisManager fetchAudioAndSpikes:(float *)&(displayVector.getPoints()[offset])+1 numFrames:numPoints stride:2];
    
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
   // NSLog(@"Num volts visible: %f", numVoltsVisible);
    
    std::vector<ci::app::TouchEvent::Touch> touches = [self getActiveTouches];
    
    // Pinching to zoom the display
    if (touches.size() == 2)
    {
        Vec2f touchDistanceDelta = [self calculateTouchDistanceChange:touches];
        float oldNumSecondsVisible = numSecondsVisible;
        float oldNumVoltsVisible = numVoltsVisible;
        
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
        
        numSecondsVisible /= (touchDistanceDelta.x - 1) + 1;
        numVoltsVisible /= (touchDistanceDelta.y - 1) + 1;
        
        // Make sure that we don't go out of bounds
        if (numSecondsVisible < 0.001) { numSecondsVisible = oldNumSecondsVisible; }
        if (numVoltsVisible < 0.001)   { numVoltsVisible = oldNumVoltsVisible; }
    }
    
    // Touching to change the threshold value
    else if (touches.size() == 1)
    {
        //thresholding
       
        Vec2f touchPos = touches[0].getPos();
        
        // Convert into voltage coordinates, and then into audio coordinates
        Vec2f worldTouchPos = [self screenToWorld:touchPos];
        
        
        
        Vec2f screenThresholdPos1 = [self worldToScreen:Vec2f(-numSecondsMin, [[BBAnalysisManager bbAnalysisManager] thresholdFirst])];
        Vec2f screenThresholdPos2 = [self worldToScreen:Vec2f(-numSecondsVisible, [[BBAnalysisManager bbAnalysisManager] thresholdSecond])];
        
        float distance1 = (touchPos.y - screenThresholdPos1.y)*(touchPos.y - screenThresholdPos1.y)+(touchPos.x - screenThresholdPos1.x)*(touchPos.x - screenThresholdPos1.x);
        float distance2 = (touchPos.y - screenThresholdPos2.y)*(touchPos.y - screenThresholdPos2.y)+(touchPos.x - screenThresholdPos2.x)*(touchPos.x - screenThresholdPos2.x);
        if (distance1 < 8500) // set via experimentation
        {
            [[BBAnalysisManager bbAnalysisManager] setThresholdFirst:worldTouchPos.y];
        }
        if (distance2 < 8500) // set via experimentation
        {
            [[BBAnalysisManager bbAnalysisManager] setThresholdSecond:worldTouchPos.y];
        }

        
    }
    
}


- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event
{
    //if touch begins remove old time interval selection
    //[[BBAudioManager bbAudioManager] endSelection];
    [super touchesBegan:touches withEvent:event];
    
}

- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event
{
    //if user just tapped on screen start and end point will
    //be the same so we will remove time interval selection
   /* if([[BBAudioManager bbAudioManager] selectionStartTime] == [[BBAudioManager bbAudioManager] selectionEndTime])
    {
        [[BBAudioManager bbAudioManager] endSelection];
    }*/
    [super touchesEnded:touches withEvent:event];
}


#pragma mark - Utility
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


// UNTESTED THUS FAR
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
