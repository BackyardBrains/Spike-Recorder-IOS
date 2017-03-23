//
//  ExperimentDCMDGraphView.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/26/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "ExperimentDCMDGraphView.h"
#import "BBChannel.h"
#import "BBSpikeTrain.h"
#import <Accelerate/Accelerate.h>
#define DEFAULT_Y_SIZE_OF_SPIKE 16
#define MIN_SIZE_OF_HISTOGRAM 150
#define GRAPH_MARGIN 10
#define SIZE_OF_BIN 0.1f
@implementation ExperimentDCMDGraphView

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
        retinaCorrection = 1/((float)[[UIScreen mainScreen] scale]);
    }
}

-(void) createGraphForExperiment:(BBDCMDExperiment *) experimentToGraph
{
    firstDrawAfterChannelChange = YES;
    currentExperiment = experimentToGraph;
    
    maxXAxis = 1.0f;
    minXAxis = -1.0f;
    yOffsetHistogram = 0.0;
    yOffsetSpikes = 0.0;
    
    BBChannel * tempChannel;
    BBSpikeTrain * tempSpikestrain;
    BBDCMDTrial * tempTrial;
    spikesCoordinatesArray = [[NSMutableArray alloc] initWithCapacity:0];
    NSArray * tempArrayOfSpikes;
    float lastRecordedTime;
    float firstAngleTime;
    

    NSSortDescriptor * sortDescriptorVelocity = [[NSSortDescriptor alloc] initWithKey:@"velocity"
                                                 ascending:YES];
    NSSortDescriptor * sortDescriptorSize = [[NSSortDescriptor alloc] initWithKey:@"size"
                                                         ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObjects:sortDescriptorSize,sortDescriptorVelocity, nil];

    NSArray *sortedArray;
    sortedArray = [[currentExperiment trials] sortedArrayUsingDescriptors:sortDescriptors];
    
    
    for(int i=0;i<[sortedArray count];i++)
    {
        tempTrial = [sortedArray objectAtIndex:i];
        tempChannel = (BBChannel *)[tempTrial.file.allChannels objectAtIndex:0];
        tempSpikestrain = (BBSpikeTrain *)[[tempChannel spikeTrains] objectAtIndex:0];
        tempArrayOfSpikes = [tempSpikestrain makeArrayOfTimestampsWithOffset:tempTrial.startOfRecording-tempTrial.timeOfImpact];
        
        
        lastRecordedTime = [((NSNumber *)[[tempTrial angles] objectAtIndex:[tempTrial.angles count]-1]) floatValue];
        firstAngleTime = [((NSNumber *)[[tempTrial angles] objectAtIndex:1]) floatValue];
        
        //Check if we need wider bounds
        if(maxXAxis<lastRecordedTime-tempTrial.timeOfImpact)
        {
            maxXAxis = lastRecordedTime-tempTrial.timeOfImpact;
        }
        if(minXAxis>firstAngleTime-tempTrial.timeOfImpact)
        {
            minXAxis = firstAngleTime-tempTrial.timeOfImpact;
        }
        
        [spikesCoordinatesArray addObject:tempArrayOfSpikes];
    }
    [sortDescriptorSize release];
    [sortDescriptorVelocity release];
    
    //Make histogram
    
    numOfPointsHistogram = (UInt32) 1+((maxXAxis-minXAxis)/SIZE_OF_BIN);
    histogramValues = (float*) malloc(sizeof(float) * numOfPointsHistogram);
    normalizedHistogramValues = (float*) malloc(sizeof(float) * numOfPointsHistogram);
    memset(histogramValues, 0, numOfPointsHistogram*sizeof(float));
    float timestamp;
    UInt32 calcIndex;
    for(int spikeTrainIndex = 0;spikeTrainIndex<[spikesCoordinatesArray count];spikeTrainIndex++)
    {
        tempArrayOfSpikes = (NSArray *)[spikesCoordinatesArray objectAtIndex:spikeTrainIndex];
        for(int spikeIndex=0;spikeIndex<[tempArrayOfSpikes count];spikeIndex++)
        {
            
            timestamp = [(NSNumber *)[tempArrayOfSpikes objectAtIndex:spikeIndex] floatValue];
            if(timestamp>=minXAxis && timestamp<=maxXAxis)
            {
                calcIndex = (UInt32)((timestamp - minXAxis)/SIZE_OF_BIN);

                histogramValues[calcIndex] +=1;
            }
        }
    }
    
    maxHistogram = 0.0f;
    for(int i=0;i<numOfPointsHistogram;i++)
    {
        histogramValues[i] = (1.0f/SIZE_OF_BIN)*(histogramValues[i]/((float)[currentExperiment.trials count]));
        if(histogramValues[i]>maxHistogram)
        {
            maxHistogram = histogramValues[i];
        }
    }
    
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
    
    if(spikesCoordinatesArray)
    {
        
        float sizeOfSpike = DEFAULT_Y_SIZE_OF_SPIKE*scaleXY.y;
        float minSizeOfHistogram = (MIN_SIZE_OF_HISTOGRAM)*scaleXY.y;
        float graphMargin = GRAPH_MARGIN*scaleXY.y;
        float overallHeightOfSpikes = [currentExperiment.trials count]*sizeOfSpike*1.5;
        yOffsetSpikes = 96.0*scaleXY.y;
        
        //If It can't fit on screen verticaly (3 GL units)
        if((yOffsetSpikes + overallHeightOfSpikes + minSizeOfHistogram + 2*graphMargin)>3.0f)
        {
            //make spikes smaller
            sizeOfSpike = (3.0f - yOffsetSpikes - minSizeOfHistogram-2*graphMargin)/((float) [currentExperiment.trials count]);//size with margin
            sizeOfSpike = (2.0f*sizeOfSpike)/3.0f;//size without margin
        }
        else
        {
            //make graph bigger to fill the screen
            minSizeOfHistogram = 3.0f-yOffsetSpikes - overallHeightOfSpikes - 2*graphMargin;
        }
        overallHeightOfSpikes = [currentExperiment.trials count]*sizeOfSpike*1.5;
        yOffsetHistogram = yOffsetSpikes + overallHeightOfSpikes + graphMargin;
        
        //------------------- Draw Histogram ------------------------
        float zoom = minSizeOfHistogram/maxHistogram;
        int i;
        //Normalize histogram and add offset
        vDSP_vsmsa (histogramValues,
                    1,
                    &zoom,
                    &yOffsetHistogram,
                    normalizedHistogramValues,
                    1,
                    numOfPointsHistogram
                    );
        
        //Draw histogram
        float binLeftXEdge = minXAxis;
        for(i=0;i<numOfPointsHistogram;i++)
        {
            
             gl::drawSolidRect(Rectf(binLeftXEdge, yOffsetHistogram, binLeftXEdge+SIZE_OF_BIN, normalizedHistogramValues[i]));
            binLeftXEdge+= SIZE_OF_BIN;
        }
        
        //------------------- Draw Spikes ----------------------------
        glLineWidth(1.0f);
        
        float timestamp;
        
        NSArray * tempSpikesArray;
        float verticalOffsetOfSpiketrain = 0.0f;
        for(i=0;i<[spikesCoordinatesArray count];i++)
        {
            tempSpikesArray = (NSArray *)[spikesCoordinatesArray objectAtIndex:i];
            for(int spikeIndex=0;spikeIndex<[tempSpikesArray count];spikeIndex++)
            {
                timestamp = [(NSNumber *)[tempSpikesArray objectAtIndex:spikeIndex] floatValue];
                if(timestamp>minXAxis && timestamp<maxXAxis)
                {
                    gl::drawLine(Vec2f(timestamp, yOffsetSpikes+verticalOffsetOfSpiketrain), Vec2f(timestamp, yOffsetSpikes+sizeOfSpike+verticalOffsetOfSpiketrain));
                }
            }
            verticalOffsetOfSpiketrain += sizeOfSpike*1.5f;
        }
        
        
        glLineWidth(2.0f);
        float xPositionOfScale = minXAxis-0.4+10*scaleXY.x;
        float sizeOfMarkXaxis = 6.0f*scaleXY.x;
        
        //--------------- Draw Y axis for Histogram ------------------
        
        gl::drawLine(Vec2f(xPositionOfScale, yOffsetHistogram), Vec2f(xPositionOfScale, yOffsetHistogram+minSizeOfHistogram ));
        gl::drawLine(Vec2f(xPositionOfScale, yOffsetHistogram), Vec2f(xPositionOfScale+sizeOfMarkXaxis, yOffsetHistogram));
        gl::drawLine(Vec2f(xPositionOfScale, yOffsetHistogram+minSizeOfHistogram), Vec2f(xPositionOfScale+sizeOfMarkXaxis, yOffsetHistogram+minSizeOfHistogram));
        
        
        //--------------- Draw Time axis line --------------------------
        
        
        float positionOfXAxis = 90.0*scaleXY.y;
        float sizeOfMark = 6.0f*scaleXY.y;
        gl::drawLine(Vec2f(minXAxis, positionOfXAxis), Vec2f(maxXAxis, positionOfXAxis));
        for(i=minXAxis;i<maxXAxis;i++)
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
        for(i=minXAxis;i<maxXAxis;i++)
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
       // gl::rotate(90.0f);
        mScaleFont->drawString(timeString.str(), xScaleTextPosition);
        
        
        //-------------- draw text for Histogram -----------------
        
        timeString.str("");
        timeString << fixed << (int)maxHistogram;
        xScaleTextSize = mScaleFont->measureString(timeString.str());
        
        xScaleTextPosition.x = 21.0-0.5f*xScaleTextSize.x;
        
        xScaleTextPosition.y =10+self.frame.size.height-retinaCorrection*(yOffsetHistogram/scaleXY.y + minSizeOfHistogram/scaleXY.y);
        mScaleFont->drawString(timeString.str(), xScaleTextPosition);
        
        timeString.str("");
        timeString << fixed << "Hz";
        xScaleTextSize = mScaleFont->measureString(timeString.str());
        
        xScaleTextPosition.x = 21.0-0.5f*xScaleTextSize.x;
        
        xScaleTextPosition.y =23+self.frame.size.height-retinaCorrection*(yOffsetHistogram/scaleXY.y + minSizeOfHistogram/scaleXY.y);
        

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
