//
//  DCMDGLView.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 8/7/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "DCMDGLView.h"
#import "UIDeviceExt.h"

#define STATE_BLANK_WAIT 1
#define STATE_RECORDING_STARTED 2
#define STATE_STIMULATION_STARTED 3
#define STATE_WHAIT_AFTER_STIMULATION 4
#define STATE_WHAIT_FOR_USER_INTERACTION 5


#define START_RECORDING_SECONDS_BEFORE 2.0f
#define WHAIT_WITH_MAX_ANGLE_SECONDS 2.0f

#define NUMBER_OF_SEGMENTS_IN_ELPISE 100

@implementation DCMDGLView


- (id)initWithFrame:(CGRect)frame andExperiment:(BBDCMDExperiment *) exp
{
    self.experiment = exp;
    return [super initWithFrame:frame ];
}


//
// Called by super on initWithFrame. It will start animation.
//
- (void)setup
{
    firstTimeStimuly = true;
    needStartTime = YES;
    trialIndex  = 0;
    startAngle = M_PI/360.0f;
    maxAngle = 80.0f*(2.0f*M_PI/360.0f);
    stateOfExp = STATE_BLANK_WAIT;
    trialIndexes = [[NSMutableArray alloc] init];
    sizesForEllipse = (float*) malloc(sizeof(float) * 10000);//size is abritrary as long as it is big enough
    for(int i=0;i<[self.experiment.trials count];i++)
    {
        [trialIndexes addObject:[NSNumber numberWithInt:i]];
    }
    pixelsPerMeter = [UIDeviceExt pixelsPerCentimeter] * 100.0f;
    NSUInteger count = [trialIndexes count];
    for (NSUInteger i = 0; i < count; ++i) {
        NSInteger remainingCount = count - i;
        NSInteger exchangeIndex = i + arc4random_uniform(remainingCount);
        [trialIndexes exchangeObjectAtIndex:i withObjectAtIndex:exchangeIndex];
    }
    
    BBDCMDTrial * tempTrial;
    for(int i=0;i<[_experiment.trials count];i++)
    {
        tempTrial = (BBDCMDTrial *)[_experiment.trials objectAtIndex:i];
        [tempTrial.angles removeAllObjects];
        angle =startAngle;//Start with one degree angle of object so theta is 0.5 degree
        //sizeOnScreen = 2.0f*tempTrial.distance*tanf(angle);
        virtualDistance = tempTrial.size/(2.0f*tanf(angle));
        currentTime = 0.0f;
        while (angle<maxAngle) {
            
            virtualDistance += tempTrial.velocity*(1.0f/60.0f);
            currentTime+=1.0f/60.0f;
            if(virtualDistance<=0.0f)
            {
                virtualDistance = 0.00000001;
            }
            angle = atanf(tempTrial.size/(2.0f*virtualDistance));
            if(angle>maxAngle)
            {
                angle = maxAngle;
            }
           
            //sizeOnScreen = 2.0f*tempTrial.distance*tanf(angle);
            [tempTrial.angles addObject:[NSNumber numberWithFloat:(float)angle*2.0]];
            [tempTrial.angles addObject:[NSNumber numberWithFloat:0.0f]];
            
        }
    }
    
    
    currentTrial = [self.experiment.trials objectAtIndex:[((NSNumber*)[trialIndexes objectAtIndex:trialIndex]) intValue]];
    currentSpeed = currentTrial.velocity;
    currentSize = currentTrial.size;
    
    
    frameRate = 200;
    [super setup];//this calls [self startAnimation]
    
    // Setup the camera
	mCam.lookAt( Vec3f(0.0f, 0.0f, 40.0f), Vec3f::zero() );
    mCam.setOrtho(0, 100, 0, 100, 1, 100);
    gl::setMatrices( mCam );
    //[self enableAntiAliasing:YES];
    [self calculateScale];
    retinaPonder = 1.0f;
    if([[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale]==2.0)
    {
        retinaPonder = 0.5;
    }
    
    
    
    [self calculateSizesForEllipseForTrial:currentTrial];
    // Make sure that we can autorotate 'n what not.
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    needStartTime = true;

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
    
   
    if(self.experiment)
    {
       

        gl::clear( Color( 1.0f, 1.0f, 1.0f ), true );
        glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
        // Look at it right
        
        if(needStartTime)
        {
            // this pair of lines is the standard way to clear the screen in OpenGL
            
            mCam.setOrtho(0, 100, 0, 100, 1, 100);
            gl::setMatrices( mCam );
            centerOfScreen = Vec2f(50.0f, 50.0f);
            needStartTime = NO;
            expStartTime = self.getElapsedSeconds;
            glColor4f(0.0f, 0.0f, 0.0f, 1.0f);
            [self calculateScale];
            NSLog(@"Setup start of experiment");
            if(firstTimeStimuly)
            {
                [self calculateSizesForEllipseForTrial:currentTrial];
                firstTimeStimuly = false;
            }
        }
        
//float fr = app::getFrameRate();
        currentTime = (float)self.getElapsedSeconds-expStartTime;
        
        switch (stateOfExp) {
            case STATE_BLANK_WAIT:
                
                if(currentTime>(self.experiment.delayBetweenTrials-START_RECORDING_SECONDS_BEFORE ))
                {
                    BBAudioManager *bbAudioManager = [BBAudioManager bbAudioManager];
                    if (bbAudioManager.recording == false) {
                        
                        //check if we have non-standard requirements for format and make custom wav
                        if([bbAudioManager sourceNumberOfChannels]>2 || [bbAudioManager sourceSamplingRate]!=44100.0f)
                        {
                            currentTrial.file = [[[BBFile alloc] initWav] autorelease];
                        }
                        else
                        {
                            //if everything is standard make .m4a file (it has beter compression )
                            currentTrial.file = [[[BBFile alloc] init] autorelease];
                        }
                        currentTrial.file.numberOfChannels = [bbAudioManager sourceNumberOfChannels];
                        currentTrial.file.samplingrate = [bbAudioManager sourceSamplingRate];
                        [currentTrial.file setupChannels];//create name of channels without spike trains
                        
                        NSLog(@"Start recording exp file URL: %@ time: %f", [currentTrial.file fileURL], currentTime);
                        [bbAudioManager startRecording:[currentTrial.file fileURL]];
                        
                        currentTrial.startOfRecording = (float)self.getElapsedSeconds-expStartTime;                        stateOfExp = STATE_RECORDING_STARTED;
                    }
                }
                break;
                
            case STATE_RECORDING_STARTED:
                
                if(currentTime>(self.experiment.delayBetweenTrials))
                {
                    NSLog(@"Stimulation Started. Time: %f", currentTime);
                    stateOfExp = STATE_STIMULATION_STARTED;
                    indexOfAngle = 0;
                }
                break;
            case STATE_STIMULATION_STARTED:
                //NSLog(@"Stimulation Started");

                [currentTrial.angles replaceObjectAtIndex:indexOfAngle+1 withObject:[NSNumber numberWithFloat:(float)currentTime]];
                if(!isRotated)
                {
                    gl::drawSolidEllipse( centerOfScreen, sizesForEllipse[indexOfAngle], sizesForEllipse[indexOfAngle+1] ,NUMBER_OF_SEGMENTS_IN_ELPISE);
                }
                else
                {
                    gl::drawSolidEllipse( centerOfScreen, sizesForEllipse[indexOfAngle+1], sizesForEllipse[indexOfAngle] , NUMBER_OF_SEGMENTS_IN_ELPISE);
                }
                
                if((indexOfAngle+=2) == maxIndexOfAngleInTrial)
                {
                    currentTrial.timeOfImpact = currentTime;
                    radiusXAxis = sizesForEllipse[indexOfAngle-2];
                    radiusYAxis = sizesForEllipse[indexOfAngle-1];
                    stateOfExp = STATE_WHAIT_AFTER_STIMULATION;
                    NSLog(@"Halt max angle started. Time: %f", currentTime);
                }
                break;
            case STATE_WHAIT_AFTER_STIMULATION:
               // NSLog(@"After stimulation");
                [currentTrial.angles addObject:[NSNumber numberWithFloat:(float)angle*2.0]];
                [currentTrial.angles addObject:[NSNumber numberWithFloat:(float)currentTime]];

                

                //Draw circle
                if(!isRotated)
                {
                    gl::drawSolidEllipse( centerOfScreen, radiusXAxis, radiusYAxis , NUMBER_OF_SEGMENTS_IN_ELPISE);
                }
                else
                {
                    gl::drawSolidEllipse( centerOfScreen, radiusYAxis, radiusXAxis , NUMBER_OF_SEGMENTS_IN_ELPISE);
                }
                
                if(currentTime> currentTrial.timeOfImpact + WHAIT_WITH_MAX_ANGLE_SECONDS)
                {
                    
                    //End of trial
                    NSLog(@"End of max angle whait. Time: %f", currentTime);
                    
                    BBAudioManager *bbAudioManager = [BBAudioManager bbAudioManager];
                    currentTrial.file.filelength = bbAudioManager.fileDuration;
                    currentTrial.file.fileUsage = EXPERIMENT_FILE_USAGE;
                    [bbAudioManager stopRecording];
                    [currentTrial.file save];
                    
                    
                    needStartTime = YES;
                    trialIndex++;
                    if(trialIndex>= [trialIndexes count])
                    {
                        stateOfExp = STATE_WHAIT_FOR_USER_INTERACTION;
                        //End of experiment
                        NSLog(@"End of experiment %@", self.experiment.name);
                        [self.controllerDelegate startSavingExperiment];
                        break;
                    }
                    currentTrial = [self.experiment.trials objectAtIndex:[((NSNumber*)[trialIndexes objectAtIndex:trialIndex]) intValue]];
 
                    [self calculateSizesForEllipseForTrial:currentTrial];
                    stateOfExp = STATE_BLANK_WAIT;
                }
                break;
                
            case STATE_WHAIT_FOR_USER_INTERACTION:
            
            break;
        }
        
        
        
        
    }
}


-(void)rotated
{
    isRotated = !isRotated;
    [self calculateScale];
}

-(void) removeAllTrialsThatAreNotSimulated
{
    NSMutableArray * tempArrayOfTrialsToDelete = [[NSMutableArray alloc] initWithCapacity:0];
    
    for(int i=trialIndex;i<[trialIndexes count];i++)
    {
            [tempArrayOfTrialsToDelete addObject:[self.experiment.trials objectAtIndex:[((NSNumber*)[trialIndexes objectAtIndex:i]) intValue]]];
    }
    for(int i=0;i<[tempArrayOfTrialsToDelete count];i++)
    {
        BBDCMDTrial * tempTrial = [tempArrayOfTrialsToDelete objectAtIndex:i];
        [[tempTrial file] deleteObject];
        [tempTrial setFile:nil];
        [tempTrial deleteObject];
        [_experiment.trials removeObject:tempTrial];
    }
    [tempArrayOfTrialsToDelete release];
}

-(void) calculateSizesForEllipseForTrial:(BBDCMDTrial *) tempTrial
{
    
    for(int i=0;i<[tempTrial.angles count];i+=2)
    {
        //sizeOnScreen = 2.0f*tempTrial.distance*tanf(([[tempTrial.angles objectAtIndex:i] floatValue]/2.0f));
        sizeOnScreen = tempTrial.distance*tanf(([[tempTrial.angles objectAtIndex:i] floatValue]/2.0f));
        // NSLog(@"[ang]%f - [m] %f - [pix] %f\n", (([[tempTrial.angles objectAtIndex:i] floatValue]/2.0f)/(2*M_PI))*360.0, sizeOnScreen, sizeOnScreen*pixelsPerMeter);
        sizesForEllipse[i] =sizeOnScreen*pixelsPerMeter*scaleXY.x;
        sizesForEllipse[i+1] =sizeOnScreen*pixelsPerMeter*scaleXY.y;
    }
    maxIndexOfAngleInTrial = [tempTrial.angles count];
    isRotated = NO;
}

- (void) restartCurrentTrial
{
    needStartTime = YES;
    stateOfExp = STATE_BLANK_WAIT;
}

- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event
{
    stateOfExp = STATE_WHAIT_FOR_USER_INTERACTION;
    BBAudioManager *bbAudioManager = [BBAudioManager bbAudioManager];
    if (bbAudioManager.recording)
    {
        currentTrial.file.fileUsage = EXPERIMENT_FILE_USAGE;
        [bbAudioManager stopRecording];
    }
    [self.controllerDelegate userWantsInterupt];
    [super touchesBegan:touches withEvent:event];
    
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

-(void) setExperiment:(BBDCMDExperiment *)myExperiment
{
    _experiment = myExperiment;
}

-(BBDCMDExperiment *) experiment
{
    return _experiment;
}

//dealloc
//sizesForEllipse
@end
