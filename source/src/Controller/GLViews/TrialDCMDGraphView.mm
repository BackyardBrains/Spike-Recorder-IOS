//
//  TrialDCMDGraphView.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/15/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "TrialDCMDGraphView.h"
#import "BBChannel.h"
#import "BBSpikeTrain.h"
#import <Accelerate/Accelerate.h>

#define Y_SIZE_OF_SPIKE 16
#define STD_OF_GAUSS 0.04
#define NUMBER_OF_POINTS_FOR_AVERAGE 500.0f

@implementation TrialDCMDGraphView

//
// Called by super on initWithFrame. It will start animation.
//
- (void)setup
{
    

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

-(void) createGraphForTrial:(BBDCMDTrial *) trialToGraph
{
    firstDrawAfterChannelChange = YES;
    currentTrial = trialToGraph;
    
    maxXAxis = 1.0f;
    minXAxis = -1.0f;
    yOffsetAngles = 1.7f;
    yOffsetAverage = 0.9f;
    yOffsetSpikes = 0.3f;
    
    
    lastRecordedTime = [((NSNumber *)[[currentTrial angles] objectAtIndex:[currentTrial.angles count]-1]) floatValue];
    firstAngleTime = [((NSNumber *)[[currentTrial angles] objectAtIndex:1]) floatValue];
    maxXAxis = lastRecordedTime-currentTrial.timeOfImpact;
    minXAxis = firstAngleTime-currentTrial.timeOfImpact;
    maxAngle = [((NSNumber *)[[currentTrial angles] objectAtIndex:[currentTrial.angles count]-2]) floatValue]/2.0;
    
    
    // Setup angles display vectors
    anglesDisplayVector = PolyLine2f();
    normalizedAngles = (float*) malloc(sizeof(float) * [currentTrial.angles count]);
    float eightyDeg = 3.14159265359*(80.0/180.0);
    for (int i=0; i < [currentTrial.angles count]-2; i+=2)
    {
        
        
        
        float x1 = [((NSNumber *)[[currentTrial angles] objectAtIndex:i+1]) floatValue]-currentTrial.timeOfImpact;
        float y1 = [((NSNumber *)[[currentTrial angles] objectAtIndex:i]) floatValue]/2.0;
        if(y1>eightyDeg)
        {
            y1 = eightyDeg;
        }
        anglesDisplayVector.push_back(Vec2f(x1,y1));
        normalizedAngles[i] = y1;
        
        
        float x2 = [((NSNumber *)[[currentTrial angles] objectAtIndex:i+3]) floatValue]-currentTrial.timeOfImpact;
        float y2 = [((NSNumber *)[[currentTrial angles] objectAtIndex:i]) floatValue]/2.0;
        if(y2>eightyDeg)
        {
            y2 = eightyDeg;
        }
        anglesDisplayVector.push_back(Vec2f(x2,y2));
        normalizedAngles[i+1] = y2;
    }
    anglesDisplayVector.setClosed(false);
    
    [self calculateIFR];
    
}


-(void) calculateIFR
{
    BBChannel * tempChannel = (BBChannel *)[currentTrial.file.allChannels objectAtIndex:0];
    BBSpikeTrain * tempSpikestrain = (BBSpikeTrain *)[[tempChannel spikeTrains] objectAtIndex:0];
    spikesCoordinate = [tempSpikestrain makeArrayOfTimestampsWithOffset:-currentTrial.startOfTrialTimestamp];
    
    
    float lStartTime = [((NSNumber *)[[currentTrial angles] objectAtIndex:1]) floatValue];
    float lEndTime = [((NSNumber *)[[currentTrial angles] objectAtIndex:[currentTrial.angles count]-1]) floatValue];
    
    float timeStep = 0.003f; //3ms
    UInt32 numOfPointsIFR = (lEndTime - lStartTime)/timeStep;
    

    int i;
    ifrResults = (float*) malloc(sizeof(float) * numOfPointsIFR);
    vDSP_vclr (ifrResults,
               1,
               numOfPointsIFR
               );
    
    float currentTime = lStartTime;
    int lastLeftSpikeIndex = 0;
    float timestamp1;
    float timestamp2;
    float ifr=0.0f;
    maxAverage = 0.0;
    
    
    //Make gauss kernel
    
    UInt32 lengthOfGauss = (UInt32)((STD_OF_GAUSS*6.0f)/timeStep);//3 STD left and right
    float xGausValue = -3.0f*STD_OF_GAUSS;
    gaussKernel = (float*) malloc(sizeof(float) * lengthOfGauss);
    float summOfGauss=0.0f;
    for(i=0;i<lengthOfGauss;i++)
    {
        gaussKernel[i] = [self normal_pdfWithX:xGausValue mean:0.0f andSTD:STD_OF_GAUSS];
        xGausValue+=timeStep;
        summOfGauss += gaussKernel[i];
    }
    //Normalize gauss
    vDSP_vsdiv (gaussKernel,
                1,
                &summOfGauss,
                gaussKernel,
                1,
                lengthOfGauss
                );
    
    
    //Calculate IFR
    
    if([spikesCoordinate count]>1)
    {
        for(i=0;i<numOfPointsIFR;i++)
        {
            
            ifr= 0.0f;
            for(int k=lastLeftSpikeIndex;k<[spikesCoordinate count]-1;k++)
            {
                lastLeftSpikeIndex = k;
                timestamp1 = [(NSNumber *)[spikesCoordinate objectAtIndex:k] floatValue];
                timestamp2 = [(NSNumber *)[spikesCoordinate objectAtIndex:k+1] floatValue];
                //if we are in interval before first spike
                if(timestamp1>currentTime)
                {
                    break;
                }
                if(timestamp2>currentTime)
                {
                    ifr = 1.0f/(timestamp2-timestamp1);
                    break;
                }
            }
            ifrResults[i] = ifr;
           
            currentTime+= timeStep;
        }
    }
    
    
    numOfPointsAverage = numOfPointsIFR - (lengthOfGauss-1);
    if(numOfPointsAverage<1)
    {
        NSLog(@"Error. Size of average graph line is less than 1.");
        return;
    }
    resultOfWindowing = (float*) malloc(sizeof(float) * numOfPointsAverage);
    
    vDSP_conv (ifrResults,
                    1,
                    gaussKernel,
                    1,
                    resultOfWindowing,
                    1,
                    numOfPointsAverage,
                    lengthOfGauss
                    );
    
    
    
    //Make point vectors for graph
    averageDisplayVector = PolyLine2f();
    currentTime = lStartTime+(lengthOfGauss/2)*timeStep;
    maxAverage = 0.0f;
    for(i=0;i<numOfPointsAverage;i++)
    {
        averageDisplayVector.push_back(Vec2f(currentTime-currentTrial.timeOfImpact,resultOfWindowing[i]));
        if(maxAverage<resultOfWindowing[i])
        {
            maxAverage = resultOfWindowing[i];
        }
        currentTime += timeStep;
    }
    averageDisplayVector.setClosed(false);
}



-(float) normal_pdfWithX:(float) x mean:(float) mean andSTD: (float) std_dev
{
    return( 1.0f/(sqrt(2.0f*M_PI)*std_dev) *
           exp(-((x-mean)*(x-mean))/(2.0f*std_dev*std_dev)) );
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
    
    
    if(firstDrawAfterChannelChange)
    {
        //this is fix for bug. Draw text starts to paint background of text
        //to the same color as text if we don't make new instance here
        //TODO: find a reason for this
        firstDrawAfterChannelChange = NO;
        mScaleFont = gl::TextureFont::create( Font("Helvetica", 12) );
    }
    
    // this pair of lines is the standard way to clear the screen in OpenGL
    gl::clear( Color( 1.0f, 1.0f, 1.0f ), true );
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    // Look at it right
    mCam.setOrtho(minXAxis-0.4, maxXAxis+0.3, 0.0f, 3.0f, 1, 100);
    gl::setMatrices( mCam );
    [self calculateScale];
    
    if(spikesCoordinate)
    {

        float sizeOfSpike = Y_SIZE_OF_SPIKE*scaleXY.y;
        yOffsetSpikes = 96.0*scaleXY.y;
        
        yOffsetAverage = yOffsetSpikes+sizeOfSpike*3.0f;
        float spaceForAngles = (3.0f-yOffsetAverage)-1.0f - 40.0*scaleXY.y;
        yOffsetAngles = yOffsetAverage+1.0 + 20.0*scaleXY.y;
        
        float zoom = 1.0f/maxAverage;

        
        vDSP_vsmsa (resultOfWindowing,
                    1,
                    &zoom,
                    &yOffsetAverage,
                    (float *)&(averageDisplayVector.getPoints()[0])+1,
                    2,
                    numOfPointsAverage
                    );

        zoom = (1.0f/maxAngle)*spaceForAngles;
        
        
        vDSP_vsmsa (normalizedAngles,
                    1,
                    &zoom,
                    &yOffsetAngles,
                    (float *)&(anglesDisplayVector.getPoints()[0])+1,
                    2,
                    [currentTrial.angles count]
                    );
        
        // Set the line color and width
        glColor4f(0.0f, 0.0f, 0.0f, 1.0f);
        glLineWidth(2.0f);

        //------------------- Draw angles ----------------------------
        gl::draw(anglesDisplayVector);
        
        
        //------------------- Draw average ---------------------------
        gl::draw(averageDisplayVector);
        
        //------------------- Draw Spikes ----------------------------
        glLineWidth(1.0f);
        int i;
        float timestamp;
        
        
        for(i=0;i<[spikesCoordinate count];i++)
        {
            timestamp = [(NSNumber *)[spikesCoordinate objectAtIndex:i] floatValue]-currentTrial.timeOfImpact;
            if(timestamp>minXAxis)
            {
                gl::drawLine(Vec2f(timestamp, yOffsetSpikes), Vec2f(timestamp, yOffsetSpikes+sizeOfSpike));
            }
        
        }

        
        glLineWidth(2.0f);
        float xPositionOfScale = minXAxis-0.4+10*scaleXY.x;
        float sizeOfMarkXaxis = 6.0f*scaleXY.x;
        
        //--------------- Draw Y axis for average ------------------
        
         gl::drawLine(Vec2f(xPositionOfScale, yOffsetAverage), Vec2f(xPositionOfScale, yOffsetAverage+1.0f));
        gl::drawLine(Vec2f(xPositionOfScale, yOffsetAverage), Vec2f(xPositionOfScale+sizeOfMarkXaxis, yOffsetAverage));
        gl::drawLine(Vec2f(xPositionOfScale, yOffsetAverage+1.0f), Vec2f(xPositionOfScale+sizeOfMarkXaxis, yOffsetAverage+1.0f));
        
        //--------------- Draw Y axis for angle ------------------
        
        gl::drawLine(Vec2f(xPositionOfScale, yOffsetAngles), Vec2f(xPositionOfScale, yOffsetAngles+spaceForAngles));
        gl::drawLine(Vec2f(xPositionOfScale, yOffsetAngles), Vec2f(xPositionOfScale+sizeOfMarkXaxis, yOffsetAngles));
        gl::drawLine(Vec2f(xPositionOfScale, yOffsetAngles+spaceForAngles), Vec2f(xPositionOfScale+sizeOfMarkXaxis, yOffsetAngles+spaceForAngles));
        
        
        //--------------- Draw Time axis line --------------------------
        
        
        float positionOfXAxis = 90.0*scaleXY.y;
        float sizeOfMark = 6.0f*scaleXY.y;
        gl::drawLine(Vec2f(minXAxis, positionOfXAxis), Vec2f(maxXAxis, positionOfXAxis));
        for(i=firstAngleTime-currentTrial.timeOfImpact;i<(lastRecordedTime-currentTrial.timeOfImpact);i++)
        {
            gl::drawLine(Vec2f((float)i, positionOfXAxis), Vec2f((float)i, positionOfXAxis-sizeOfMark));
        }
        
        //------------------ Impact time line ------------------------------
        float yImpactMark;
        float endImpactMark = 3.0f-15.0f*scaleXY.y;
        float sizeOfImpactMark = 6.0f*scaleXY.y;

        glColor4f(1.0f, 0.0f, 0.0f, 1.0f);
        glLineWidth(2.0f);
        
        for(yImpactMark=positionOfXAxis;yImpactMark<endImpactMark;yImpactMark+=2.0*sizeOfImpactMark)
        {
            gl::drawLine(Vec2f(0.0f, yImpactMark), Vec2f(0.0f, yImpactMark+sizeOfImpactMark));
        }
        
        
        
        glColor4f(0.0f, 0.0f, 0.0f, 1.0f);
        //========== Draw scale text ==================
        
        //Text for X axis - Time
        
        gl::disableDepthRead();
        gl::setMatricesWindow( Vec2i(self.frame.size.width, self.frame.size.height) );
        gl::enableAlphaBlending();
        
        
        
        //---------------  Draw text for time ------------------------------
 
        std::stringstream timeString;
        timeString.precision(1);
        Vec2f xScaleTextSize;
        Vec2f xScaleTextPosition = Vec2f(0.,0.);
        glLineWidth(2.0f);
        for(i=firstAngleTime-currentTrial.timeOfImpact;i<(lastRecordedTime-currentTrial.timeOfImpact);i++)
        {
            //draw number
            
            timeString.str("");
            timeString << fixed << i;
            xScaleTextSize = mScaleFont->measureString(timeString.str());

            xScaleTextPosition.x = ( -(minXAxis-0.4)/scaleXY.x + ((float)(i))/scaleXY.x)*retinaCorrection -xScaleTextSize.x*0.5 ;
            xScaleTextPosition.y =self.frame.size.height-33;
            mScaleFont->drawString(timeString.str(), xScaleTextPosition);
            
        }
        
        timeString.str("");
        timeString << fixed << "Time to impact (S)";
        xScaleTextSize = mScaleFont->measureString(timeString.str());
        
        xScaleTextPosition.x = 0.5*(self.frame.size.width - xScaleTextSize.x) ;
        
        xScaleTextPosition.y =self.frame.size.height-13;
        mScaleFont->drawString(timeString.str(), xScaleTextPosition);
        
        
        //-------------- draw text for angles -----------------

        timeString.str("");
        timeString << fixed << "80";
        xScaleTextSize = mScaleFont->measureString(timeString.str());
        
        xScaleTextPosition.x = 21.0-0.5f*xScaleTextSize.x;
        
        xScaleTextPosition.y =self.frame.size.height-retinaCorrection*(yOffsetAngles/scaleXY.y + (spaceForAngles*0.5)/scaleXY.y);
        mScaleFont->drawString(timeString.str(), xScaleTextPosition);
        
        timeString.str("");
        timeString << fixed << "deg";
        xScaleTextSize = mScaleFont->measureString(timeString.str());
        
        xScaleTextPosition.x = 21.0-0.5f*xScaleTextSize.x;
        
        xScaleTextPosition.y =13+self.frame.size.height-retinaCorrection*(yOffsetAngles/scaleXY.y + (spaceForAngles*0.5)/scaleXY.y);
        mScaleFont->drawString(timeString.str(), xScaleTextPosition);
        
        //-------------- draw text for frequency -----------------
        
        timeString.str("");
        timeString << fixed << (int)maxAverage;
        xScaleTextSize = mScaleFont->measureString(timeString.str());
        
        xScaleTextPosition.x = 21.0-0.5f*xScaleTextSize.x;
        
        xScaleTextPosition.y =self.frame.size.height-retinaCorrection*((yOffsetAverage+0.5f)/scaleXY.y );
        mScaleFont->drawString(timeString.str(), xScaleTextPosition);
        
        timeString.str("");
        timeString << fixed << "Hz";
        xScaleTextSize = mScaleFont->measureString(timeString.str());
        
        xScaleTextPosition.x = 21.0-0.5f*xScaleTextSize.x;
        
        xScaleTextPosition.y =13+self.frame.size.height-retinaCorrection*((yOffsetAverage+0.5f)/scaleXY.y);
        mScaleFont->drawString(timeString.str(), xScaleTextPosition);
    
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
