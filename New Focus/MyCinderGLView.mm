//
//  MyCinderGLView.mm
//  CCGLTouchBasic example
//
//  More info on the CCGLTouch project >> http://www.smallab.org/code/ccgl-touch/
//  License & disclaimer >> see license.txt file included in the distribution package
//

#import "MyCinderGLView.h"
#import "BBSpike.h"
@interface MyCinderGLView ()
{
    BBAudioManager *audioManager;
    float destNumSecondsVisible; // used for short animations of scaling the plot
    float touchStartTime;
    BOOL weAreDrawingSelection;
    float timeForSincDrawing;
}

- (Vec2f)calculateTouchDistanceChange:(std::vector<ci::app::TouchEvent::Touch>)touches;
- (void)fillDisplayVector;
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
	
    [self loadSettings:FALSE];
    
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

- (void)loadSettings:(BOOL)useThresholdSettings
{
    
    NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Initialize parameters
    if (useThresholdSettings) {
        NSLog(@"Setting threshold defaults");
        numSecondsMax = [[defaults valueForKey:@"numSecondsMaxThreshold"] floatValue];
        numSecondsMin = [[defaults valueForKey:@"numSecondsMinThreshold"] floatValue];
        numSecondsVisible = [[defaults valueForKey:@"numSecondsVisibleThreshold"] floatValue];
        numVoltsMin = [[defaults valueForKey:@"numVoltsMinThreshold"] floatValue];
        numVoltsMax = [[defaults valueForKey:@"numVoltsMaxThreshold"] floatValue];
        numVoltsVisible = [[defaults valueForKey:@"numVoltsVisibleThreshold"] floatValue];
    }
    else {
        numSecondsMax = [[defaults valueForKey:@"numSecondsMax"] floatValue];
        numSecondsMin = [[defaults valueForKey:@"numSecondsMin"] floatValue];
        numSecondsVisible = [[defaults valueForKey:@"numSecondsVisible"] floatValue];
        numVoltsMin = [[defaults valueForKey:@"numVoltsMin"] floatValue];
        numVoltsMax = [[defaults valueForKey:@"numVoltsMax"] floatValue];
        numVoltsVisible = [[defaults valueForKey:@"numVoltsVisible"] floatValue];
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
        [defaults setValue:[NSNumber numberWithFloat:numSecondsMax] forKey:@"numSecondsMaxThreshold"];
        [defaults setValue:[NSNumber numberWithFloat:numSecondsMin] forKey:@"numSecondsMinThreshold"];
        [defaults setValue:[NSNumber numberWithFloat:numSecondsVisible] forKey:@"numSecondsVisibleThreshold"];
        [defaults setValue:[NSNumber numberWithFloat:numVoltsMin] forKey:@"numVoltsMinThreshold"];
        [defaults setValue:[NSNumber numberWithFloat:numVoltsMax] forKey:@"numVoltsMaxThreshold"];
        [defaults setValue:[NSNumber numberWithFloat:numVoltsVisible] forKey:@"numVoltsVisibleThreshold"];
    }
    else {
        [defaults setValue:[NSNumber numberWithFloat:numSecondsMax] forKey:@"numSecondsMax"];
        [defaults setValue:[NSNumber numberWithFloat:numSecondsMin] forKey:@"numSecondsMin"];
        [defaults setValue:[NSNumber numberWithFloat:numSecondsVisible] forKey:@"numSecondsVisible"];
        [defaults setValue:[NSNumber numberWithFloat:numVoltsMin] forKey:@"numVoltsMin"];
        [defaults setValue:[NSNumber numberWithFloat:numVoltsMax] forKey:@"numVoltsMax"];
        [defaults setValue:[NSNumber numberWithFloat:numVoltsVisible] forKey:@"numVoltsVisible"];
    }
    
    [defaults synchronize];
}

- (void)draw {
    
    // this pair of lines is the standard way to clear the screen in OpenGL
	gl::clear( Color( 0.0f, 0.0f, 0.0f ), true );
	glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    
    
    // Look at it right
    mCam.setOrtho(-numSecondsVisible, -numSecondsMin, -numVoltsVisible/2.0f, numVoltsVisible/2.0f, 1, 100);;
    gl::setMatrices( mCam );
    
    // Draw selection area
    std::stringstream timeStream;
    std::stringstream rmstream;
    weAreDrawingSelection = [[BBAudioManager bbAudioManager] selecting] &&  [[BBAudioManager bbAudioManager] selectionStartTime] != [[BBAudioManager bbAudioManager] selectionEndTime] && ![[BBAudioManager bbAudioManager] playing] && ![[BBAudioManager bbAudioManager] viewAndRecordFunctionalityActive];
    if(weAreDrawingSelection)
    {
        glLineWidth(1.0f);
        
        float sStartTime;
        float sEndTime;
        //Order time points in right way
        if([[BBAudioManager bbAudioManager] selectionStartTime]>[[BBAudioManager bbAudioManager] selectionEndTime])
        {
            sStartTime = [[BBAudioManager bbAudioManager] selectionEndTime];
            sEndTime = [[BBAudioManager bbAudioManager] selectionStartTime];
        }
        else
        {
            sStartTime = [[BBAudioManager bbAudioManager] selectionStartTime];
            sEndTime = [[BBAudioManager bbAudioManager] selectionEndTime];
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
        float rmsToDisplay = [[BBAudioManager bbAudioManager] rmsOfSelection];
        
        rmstream.precision(3);
        rmstream <<"RMS: "<< fixed << rmsToDisplay << " mV";
        
        
        //draw background of selected region
        glColor4f(0.4, 0.4, 0.4, 0.5);
        gl::disableDepthRead();
        gl::drawSolidRect(Rectf(sStartTime, -numVoltsVisible, sEndTime, numVoltsVisible),false);
        
        //draw limit lines
        glColor4f(0.8, 0.8, 0.8, 1.0);
        gl::drawLine(Vec2f(sStartTime, -numVoltsVisible), Vec2f(sStartTime, numVoltsVisible));
        gl::drawLine(Vec2f(sEndTime, -numVoltsVisible), Vec2f(sEndTime, numVoltsVisible));
        gl::enableDepthRead();
    }

    
    // Set the line color and width
    glColor4f(0.0f, 1.0f, 0.0f, 1.0f);
    glLineWidth(1.0f);
    
    // Put the audio on the screen

    [self fillDisplayVector];
    gl::draw(displayVector);
    //draw spikes on the screen
    [self drawSpikes];


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
    [self drawScaleTextAndSelected:&timeStream andRms:&rmstream];
    

    
}


-(void) drawSpikes
{
    gl::enableDepthRead();
    float currentTime = timeForSincDrawing ;
    if(![[BBAudioManager bbAudioManager] playing])
    {
        currentTime = [[BBAudioManager bbAudioManager] getTimeForSpikes];
    }
   // NSLog(@"D: %f", currentTime);
    NSMutableArray* spikes;
    if((spikes = [[BBAudioManager bbAudioManager] getSpikes])!=nil)
    {
        Vec2f refSizeS = [self worldToScreen:Vec2f(-numSecondsMin,0.0)];
        Vec2f refSizeW = [self screenToWorld:Vec2f(refSizeS.x-10,refSizeS.y+10)];
        float tenPixX =refSizeW.x+numSecondsMin;
        float tenPixY =refSizeW.y;
        //Draw spikes
        glColor4f(1.0f, 0.0f, 0.0f, 1.0f);
        BOOL weAreInInterval = NO;
        float sizeOfPointX = 0.3*tenPixX;
        float sizeOfPointY = 0.3*tenPixY;

        
        float startTimeToDisplay = currentTime-((numSecondsVisible> numSecondsMax)?numSecondsMax:numSecondsVisible);
        float endTimeToDisplay = currentTime;
        BBSpike * tempSpike;
        NSMutableArray * tempSpikeTrain;
        int i=0;
        for(tempSpikeTrain in spikes)
        {
            weAreInInterval = NO;
            [self setColorWithIndex:i transparency:1.0f];
            i++;
            for (tempSpike in tempSpikeTrain) {
                if([tempSpike time]>startTimeToDisplay && [tempSpike time]<endTimeToDisplay)
                {
                    weAreInInterval = YES;
                    gl::drawSolidRect(Rectf([tempSpike time]-sizeOfPointX-endTimeToDisplay,[tempSpike value]-sizeOfPointY,[tempSpike time]+sizeOfPointX-endTimeToDisplay,[tempSpike value]+sizeOfPointY));
                }
                else if(weAreInInterval)
                {
                    break;
                }
            }
        }
    }
}


-(void) setColorWithIndex:(int) iindex transparency:(float) transp
{
    iindex = iindex%5;
    switch (iindex) {
        case 0:
            glColor4f(1.0f, 0.0f, 0.0f, transp);
            break;
        case 1:
            glColor4f(0.0f, 0.0f, 1.0f, transp);
            break;
        case 2:
            glColor4f(0.0f, 1.0f, 1.0f, transp);
            break;
        case 3:
            glColor4f(1.0f, 1.0f, 0.0f, transp);
            break;
        case 4:
            glColor4f(1.0f, 0.0f, 1.0f, transp);
            break;
    }
    
}


- (void)drawScaleTextAndSelected:(std::stringstream *) timeStream andRms:(std::stringstream *) rmsStream
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
    
    
    // Draw the x-axis scale text
    if (weAreDrawingSelection) {

        //Draw time ---------------------------------------------
        
        //if we are measuring draw measure result at the bottom
        Vec2f xScaleTextSize = mScaleFont->measureString(timeStream->str());
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
        glColor4f(0.0, 0.0, 1.0, 1.0);
        float centerx = self.frame.size.width/2;
        
        //draw background rectangle
        gl::enableDepthRead();
         gl::drawSolidRect(Rectf(centerx-3*xScaleTextSize.y,xScaleTextPosition.y-1.1*xScaleTextSize.y,centerx+3*xScaleTextSize.y,xScaleTextPosition.y+0.4*xScaleTextSize.y));
        gl::disableDepthRead();
        gl::color( ColorA( 1.0, 1.0f, 1.0f, 1.0f ) );
        //draw text
        mScaleFont->drawString(timeStream->str(), xScaleTextPosition);
        
        
        //Draw RMS -------------------------------------------------
        float xpositionOfCenterOfRMSBackground;

        Vec2f rmsTextSize = mScaleFont->measureString(rmsStream->str());
        xpositionOfCenterOfRMSBackground = self.frame.size.width-4.25*rmsTextSize.y;
        Vec2f rmsTextPosition = Vec2f(0.,0.);
        rmsTextPosition.x = (xpositionOfCenterOfRMSBackground - 0.5*rmsTextSize.x);
        //if it is iPad put it on the right
                UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad || UIInterfaceOrientationIsLandscape(interfaceOrientation)) {
            rmsTextPosition.y =xScaleTextPosition.y;
        }
        else
        {
           rmsTextPosition.y =0.23*self.frame.size.height + (mScaleFont->getAscent() / 2.0f);
        }
        glColor4f(0.0, 0.0, 0.0, 1.0);

        
        //draw background rectangle
        gl::enableDepthRead();
        gl::drawSolidRect(Rectf(self.frame.size.width-8*rmsTextSize.y,rmsTextPosition.y-1.1*rmsTextSize.y,self.frame.size.width-0.5*rmsTextSize.y,rmsTextPosition.y+0.4*rmsTextSize.y));
        gl::disableDepthRead();
        gl::color( ColorA( 0.0, 1.0f, 0.0f, 1.0f ) );
        //draw text
        mScaleFont->drawString(rmsStream->str(), rmsTextPosition);
        
        
        
    }
    else
    {
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
 
    }
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
    
    // See if we're asking for TOO MANY points
    int numPoints, offset;
    if (numSecondsVisible > numSecondsMax) {
        numPoints = numSecondsMax * audioManager.samplingRate;
        offset = 0;
        
        if ([self getActiveTouches].size() != 2)
            numSecondsVisible += 0.6 * (numSecondsMax - numSecondsVisible);//animation to max seconds
    }
    
    // See if we're asking for TOO FEW points
    else if (numSecondsVisible < numSecondsMin)
    {
        numPoints = numSecondsMin * audioManager.samplingRate;
        offset = 0;
        
        if ([self getActiveTouches].size() != 2)
            numSecondsVisible += 0.6 * (numSecondsMin*2.0 - numSecondsVisible);//animation to min sec
        
    }
    
    // If we haven't set off any of the alarms above,
    // then we're asking for a normal range of points.
    else {
        numPoints = numSecondsVisible * audioManager.samplingRate;//visible part
        offset = numSecondsMax * audioManager.samplingRate - numPoints;//nonvisible part
        if ([[BBAudioManager bbAudioManager] thresholding]) {
            offset -= (numSecondsMin * audioManager.samplingRate)/2.0f;
        }
    }
    
    // Aight, now that we've got our ranges correct, let's ask for the audio.
    //Only fetch visible part (numPoints samples) and put it after offset.
    //Stride is equal to 2 since we have x and y coordinatesand we want to set only y
    timeForSincDrawing =  [audioManager fetchAudio:(float *)&(displayVector.getPoints()[offset])+1 numFrames:numPoints whichChannel:0 stride:2];

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
    NSLog(@"Num volts visible: %f", numVoltsVisible);

    std::vector<ci::app::TouchEvent::Touch> touches = [self getActiveTouches];
    
    // Pinching to zoom the display
    if (touches.size() == 2)
    {
        Vec2f touchDistanceDelta = [self calculateTouchDistanceChange:touches];
        float oldNumSecondsVisible = numSecondsVisible;
        float oldNumVoltsVisible = numVoltsVisible;
        numSecondsVisible /= (touchDistanceDelta.x - 1) + 1;
        numVoltsVisible /= (touchDistanceDelta.y - 1) + 1;
        
        // Make sure that we don't go out of bounds
        if (numSecondsVisible < 0.001) { numSecondsVisible = oldNumSecondsVisible; }
        if (numVoltsVisible < 0.001)   { numVoltsVisible = oldNumVoltsVisible; }
        
        // If we are thresholding,
        // we will not allow the springy x-axis effect to occur
        // (why? we always want the x-axis to be centered on the threshold value)
        if ([[BBAudioManager bbAudioManager] thresholding]) {
            // slightly tigher bounds on the thresholding view (don't need to see whole second and a half in this view)
            // TODO: this is a hack to get thresholding to have a separate number of seconds visible. I weep for how awful this is. I am so sorry.
            float thisNumSecondsMax = 1.5;
            numSecondsVisible = (numSecondsVisible < thisNumSecondsMax - 0.25) ? numSecondsVisible : (thisNumSecondsMax - 0.25);
            numSecondsVisible = (numSecondsVisible > numSecondsMin) ? numSecondsVisible : numSecondsMin;
        }
        
    }
    
    // Touching to change the threshold value, if we're thresholding
    //Selecting time interval and thresholding are mutualy exclusive
    else if (touches.size() == 1)
    {
        BOOL changingThreshold;
        changingThreshold = false;
        
        //thresholding
        if ([[BBAudioManager bbAudioManager] thresholding] && ![[BBAudioManager bbAudioManager] selecting]) {
            Vec2f touchPos = touches[0].getPos();
            float currentThreshold = [[BBAudioManager bbAudioManager] threshold];
            
            // Convert into voltage coordinates, and then into audio coordinates
            Vec2f worldTouchPos = [self screenToWorld:touchPos];
            Vec2f screenThresholdPos = [self worldToScreen:Vec2f(0.0f, currentThreshold)];
            
            float distance = abs(touchPos.y - screenThresholdPos.y);
            if (distance < 20) // set via experimentation
            {
                changingThreshold = true;
                [[BBAudioManager bbAudioManager] setThreshold:worldTouchPos.y];
            }
        }
        
        //selecting time interval
        if(!changingThreshold && ![[BBAudioManager bbAudioManager] playing] && ![[BBAudioManager bbAudioManager] viewAndRecordFunctionalityActive])
        {
            Vec2f touchPos = touches[0].getPos();
            
            // Convert into time coordinate
            Vec2f worldTouchPos = [self screenToWorld:touchPos];
            [[BBAudioManager bbAudioManager] updateSelection:worldTouchPos.x];
        }
        
    }

}


- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event
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
