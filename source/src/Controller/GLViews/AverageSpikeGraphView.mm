//
//  AverageSpikeGraphView.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/27/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "AverageSpikeGraphView.h"
#define GRAPH_MARGIN 10

@implementation AverageSpikeGraphView



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
    if([[UIScreen mainScreen] respondsToSelector:@selector(scale)] )
    {//if it is retina correct scale
        retinaCorrection = 1/(float)[[UIScreen mainScreen] scale];
    }
    firstDrawAfterChange = YES;
}

//Just for reference
/*typedef struct _averageSpikeData {
	
	PolyLine2f averageSpike;//index of end of fresh data in segment
    float graphOffset;
    float maxAverageSpike;
    float minAverageSpike;
    float * topSTDLine;
    float * bottomSTDLine;
    float maxStd;
    float minStd;
    PolyLine2f ** allSpikes;
    float maxAllSpikes;
    float minAllSpikes;
} AverageSpikeData;
*/

-(void) createGraphForFile:(BBFile * )newFile andChannelIndex:(int) newChannelIndex
{
    indexOfChannel = newChannelIndex;
    currentFile = newFile;
    numberOfGraphs = [(NSMutableArray *)[(BBChannel *)[[newFile allChannels] objectAtIndex:newChannelIndex] spikeTrains] count];
    if(numberOfGraphs>0)
    {
        spikes = [[BBAnalysisManager bbAnalysisManager] getAverageSpikesForChannel:newChannelIndex inFile:newFile];
        lengthOfGraphData = spikes[0].numberOfSamplesInData;
        float oneSampleLength =(1.0f/((float)spikes[0].samplingRate));
        minXAxis = oneSampleLength*(((float)lengthOfGraphData)*-0.5);
        maxXAxis = oneSampleLength*(((float)lengthOfGraphData)*0.5);
        
        tempGraph = PolyLine2f();
        
        float xValue = minXAxis;
        
        for (int i=0; i < lengthOfGraphData; ++i)
        {
            tempGraph.push_back(Vec2f(xValue, 0.0f));
            xValue+= oneSampleLength;
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

- (void)dealloc
{
    [super dealloc];
}

//
// Draw graph
//
- (void)draw {
    
    
    if(firstDrawAfterChange)
    {
        //this is fix for bug. Draw text starts to paint background of text
        //to the same color as text if we don't make new instance here
        //TODO: find a reason for this
        firstDrawAfterChange = NO;
        mScaleFont = nil;
        mScaleFont = gl::TextureFont::create( Font("Helvetica", 12) );
    }
    
    // this pair of lines is the standard way to clear the screen in OpenGL
    gl::clear( Color( 0.0f, 0.0f, 0.0f ), true );
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    // Look at it right
    float xsize = maxXAxis-minXAxis;
    mCam.setOrtho(minXAxis-0.05*xsize, maxXAxis-0.05*xsize, 0.0f, 3.0f, 1, 100);
    gl::setMatrices( mCam );
    [self calculateScale];
    float xPositionOfScale = minXAxis-0.05*xsize+10*scaleXY.x;
    float sizeOfMarkXaxis = 6.0f*scaleXY.x;
    if(spikes)
    {
        
        
        
        baseYOffset = 96.0*scaleXY.y;
        float graphMargin = GRAPH_MARGIN*scaleXY.y;
        float sizeOfOneGraph = (3.0f-(numberOfGraphs+1)*graphMargin - baseYOffset)/numberOfGraphs;
        
        //------------------- Draw Averages and STD ------------------------
        float zoom;
        float actualOffSet;
        int i;
        for(i=0;i<numberOfGraphs;i++)
        {
            baseYOffset+= graphMargin;
            
            zoom = sizeOfOneGraph/(spikes[i].maxStd-spikes[i].minStd);
            actualOffSet = baseYOffset-spikes[i].minStd * zoom;
            //Normalize graph and add offset
            vDSP_vsmsa (spikes[i].averageSpike,
                        1,
                        &zoom,
                        &actualOffSet,
                        (float *)&(tempGraph.getPoints()[0])+1,
                        2,
                        lengthOfGraphData
                        );
            
            //draw  STD
            [self setGLColor:[BYBGLView getSpikeTrainColorWithIndex:i transparency:1.0f]];

            for(int j=0;j<lengthOfGraphData;j++)
            {
                /*gl::drawLine(Vec2f(tempGraph.getPoints()[j].x, spikes[i].bottomSTDLine[j]*zoom + actualOffSet), Vec2f(tempGraph.getPoints()[j].x, spikes[i].topSTDLine[j]*zoom + actualOffSet));*/
                gl::drawSolidRect( Rectf(tempGraph.getPoints()[j].x,spikes[i].bottomSTDLine[j]*zoom + actualOffSet,tempGraph.getPoints()[j].x+tempGraph.getPoints()[1].x-tempGraph.getPoints()[0].x,spikes[i].topSTDLine[j]*zoom + actualOffSet));
                
            }
            
            
            //Draw average
            glColor4f(0.0f, 0.0f, 0.0f, 1.0f);
            //[self setGLColor:[BYBGLView getSpikeTrainColorWithIndex:i transparency:1.0f]];
            glLineWidth(3.0f);
            gl::draw(tempGraph);
            
           
           
           /* glColor4f(0.9686274509803922f, 0.4980392156862745f, 0.011764705882352941f, 1.0f);
            glLineWidth(1.0f);
            vDSP_vsmsa (spikes[i].bottomSTDLine,
                        1,
                        &zoom,
                        &actualOffSet,
                        (float *)&(tempGraph.getPoints()[0])+1,
                        2,
                        lengthOfGraphData
                        );
            //draw bottom line STD
            gl::draw(tempGraph);
            
            //draw top STD
            vDSP_vsmsa (spikes[i].topSTDLine,
                        1,
                        &zoom,
                        &actualOffSet,
                        (float *)&(tempGraph.getPoints()[0])+1,
                        2,
                        lengthOfGraphData
                        );
            //Draw top line STD
            gl::draw(tempGraph);*/
            
            //Draw Y axis
            glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
            float bottomY = spikes[i].minAverageSpike*zoom+actualOffSet;
            float topY = spikes[i].maxAverageSpike*zoom+actualOffSet;
            gl::drawLine(Vec2f(xPositionOfScale, bottomY), Vec2f(xPositionOfScale, topY ));
            gl::drawLine(Vec2f(xPositionOfScale, bottomY), Vec2f(xPositionOfScale+sizeOfMarkXaxis, bottomY));
            gl::drawLine(Vec2f(xPositionOfScale, topY), Vec2f(xPositionOfScale+sizeOfMarkXaxis, topY));

            baseYOffset+=sizeOfOneGraph;
        }
        
     
        
        
        glLineWidth(2.0f);

        //--------------- Draw Time axis line --------------------------
        
        glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
        float positionOfXAxis = 90.0*scaleXY.y;
        float sizeOfMark = 6.0f*scaleXY.y;
        gl::drawLine(Vec2f(minXAxis, positionOfXAxis), Vec2f(maxXAxis, positionOfXAxis));
        float positionOfMark;
        
        for(positionOfMark=minXAxis;positionOfMark<maxXAxis;positionOfMark+=0.001)
        {
            positionOfMark = ceil(positionOfMark*1000);
            positionOfMark = positionOfMark/1000.0f;
            gl::drawLine(Vec2f(positionOfMark, positionOfXAxis), Vec2f(positionOfMark, positionOfXAxis-sizeOfMark));
        }
        
        
        glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
        
        
        
        //========== Draw scale text ==================
    
        gl::disableDepthRead();
        gl::setMatricesWindow( Vec2i(self.frame.size.width, self.frame.size.height) );
        gl::enableAlphaBlending();
        
        //---------------  Draw text for time ------------------------------
        
        std::stringstream timeString;
        timeString.precision(1);
        Vec2f xScaleTextSize;
        Vec2f xScaleTextPosition = Vec2f(0.,0.);
        glLineWidth(2.0f);
        for(positionOfMark=minXAxis;positionOfMark<maxXAxis;positionOfMark+=0.001)
        {
            positionOfMark = ceil(positionOfMark*1000);
            positionOfMark = positionOfMark/1000.0f;
            timeString.str("");
            timeString << fixed << (int) (positionOfMark*1000.0f);
            xScaleTextSize = mScaleFont->measureString(timeString.str());
            
            xScaleTextPosition.x = ( -(minXAxis-0.05*xsize)/scaleXY.x + positionOfMark/scaleXY.x)*retinaCorrection -xScaleTextSize.x*0.5 ;
            xScaleTextPosition.y =self.frame.size.height-33;
            mScaleFont->drawString(timeString.str(), xScaleTextPosition);
            
        }
        
        timeString.str("");
        timeString << fixed << "Time (ms)";
        xScaleTextSize = mScaleFont->measureString(timeString.str());
        
        xScaleTextPosition.x = 0.5*(self.frame.size.width - xScaleTextSize.x) ;
        
        xScaleTextPosition.y =self.frame.size.height-13;
        // gl::rotate(90.0f);
        mScaleFont->drawString(timeString.str(), xScaleTextPosition);
        
        
        //-------------- draw text for Y axis of graphs -----------------
        
        baseYOffset = 96.0*scaleXY.y;
        
        for(i=0;i<numberOfGraphs;i++)
        {
            baseYOffset+= graphMargin;
            zoom = sizeOfOneGraph/(spikes[i].maxStd-spikes[i].minStd);
            actualOffSet = baseYOffset-spikes[i].minStd * zoom;
            float sizeToTop = spikes[i].maxAverageSpike*zoom+actualOffSet;
            timeString.str("");
            //timeString.precision(2);
            float yScale = (spikes[i].maxAverageSpike-spikes[i].minAverageSpike);
            if(yScale>=0.2f)
            {
                timeString.precision(2);
                timeString << fixed << ((spikes[i].maxAverageSpike-spikes[i].minAverageSpike)) << "V";
                xScaleTextSize = mScaleFont->measureString(timeString.str());
                xScaleTextPosition.x = 25.0-0.5f*xScaleTextSize.x;
                xScaleTextPosition.y =10+self.frame.size.height-retinaCorrection*(sizeToTop/scaleXY.y);
                mScaleFont->drawString(timeString.str(), xScaleTextPosition);
            }
            else
            {
                timeString << fixed << (int)((spikes[i].maxAverageSpike-spikes[i].minAverageSpike)*1000.0f);
                xScaleTextSize = mScaleFont->measureString(timeString.str());
                xScaleTextPosition.x = 21.0-0.5f*xScaleTextSize.x;
                xScaleTextPosition.y =10+self.frame.size.height-retinaCorrection*(sizeToTop/scaleXY.y);
                mScaleFont->drawString(timeString.str(), xScaleTextPosition);
                timeString.str("");
                timeString << fixed << "mV";
                xScaleTextSize = mScaleFont->measureString(timeString.str());
                xScaleTextPosition.x = 21.0-0.5f*xScaleTextSize.x;
                xScaleTextPosition.y =23+self.frame.size.height-retinaCorrection*(sizeToTop/scaleXY.y);
                mScaleFont->drawString(timeString.str(), xScaleTextPosition);
            }
            
            baseYOffset+=sizeOfOneGraph;
        }
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
