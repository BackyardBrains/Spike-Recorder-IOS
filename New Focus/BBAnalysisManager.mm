//
//  BBAnalysisManager.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/10/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "BBAnalysisManager.h"
#import "BBSpike.h"
#import <Accelerate/Accelerate.h>
#define RING_BUFFER_SIZE 524288

#define kSchmittON 1
#define kSchmittOFF 2


static BBAnalysisManager *bbAnalysisManager = nil;

@interface BBAnalysisManager ()
{
    __block BBAudioFileReader *fileReader;
    DSPAnalysis *dspAnalizer;
    float * tempCalculationBuffer;//used to load data for display while scrubbing
    BBFile * _file;
}
@end


@implementation BBAnalysisManager

@synthesize fileToAnalyze;
@synthesize threshold1;
@synthesize threshold2;

#pragma mark - Singleton Methods
+ (BBAnalysisManager *) bbAnalysisManager
{
	@synchronized(self)
	{
		if (bbAnalysisManager == nil) {
			bbAnalysisManager = [[BBAnalysisManager alloc] init];
		}
	}
    return bbAnalysisManager;
}

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (bbAnalysisManager == nil) {
            bbAnalysisManager = [super allocWithZone:zone];
            return bbAnalysisManager;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain {
    return self;
}

- (unsigned)retainCount {
    return UINT_MAX;  // denotes an object that cannot be released
}

- (oneway void)release {
    //do nothing
}


- (id)init
{
    if (self = [super init])
    {

        tempCalculationBuffer = (float *)calloc(RING_BUFFER_SIZE, sizeof(float));
        dspAnalizer = new DSPAnalysis();
        self.threshold1 = 0;
        self.threshold2 = 0;
    }
    
    return self;
}

#pragma mark - Data fetch

-(void) prepareFileForSelection:(BBFile *)aFile
{
    _file = aFile;
    if (fileReader != nil)
        fileReader = nil;
    
    
    fileReader = [[BBAudioFileReader alloc]
                  initWithAudioFileURL:[aFile fileURL]
                  samplingRate:aFile.samplingrate
                  numChannels:1];

}

- (void)fetchAudioAndSpikes:(float *)data numFrames:(UInt32)numFrames whichChannel:(UInt32)whichChannel stride:(UInt32)stride
{
    UInt32 targetFrame = (UInt32)(fileReader.currentTime * ((float)fileReader.samplingRate));
    int startFrame = targetFrame - numFrames;
    if(startFrame<0)
    {
        startFrame = 0;
    }
    memset(tempCalculationBuffer, 0, RING_BUFFER_SIZE*sizeof(float));
    int numberOfSamplesToread = targetFrame-startFrame;
    [fileReader retrieveFreshAudio:tempCalculationBuffer+numFrames-numberOfSamplesToread numFrames:numberOfSamplesToread numChannels:1 seek:startFrame];

    float zero = 0.0f;
    vDSP_vsadd(tempCalculationBuffer,
               1,
               &zero,
               data,
               stride,
               numFrames);
    
}


#pragma mark - Analysis

- (int)findSpikes:(BBFile *)aFile
{
    _file = aFile;
    if (fileReader != nil)
        fileReader = nil;
    

    fileReader = [[BBAudioFileReader alloc]
                  initWithAudioFileURL:[aFile fileURL]
                  samplingRate:aFile.samplingrate
                  numChannels:1];
    
    
    int numberOfSamples = (int)(fileReader.duration * aFile.samplingrate);
    int numberOfBins = 200;
    int lengthOfBin = numberOfSamples/numberOfBins;

    if(lengthOfBin>RING_BUFFER_SIZE)
    {
        lengthOfBin = RING_BUFFER_SIZE;
        numberOfBins = ceil((float)numberOfSamples/(float)lengthOfBin);
    }
    
    if(lengthOfBin<50)
    {
        NSLog(@"findSpikes: File too short.");
        return -1;
    }
    
    float *stdArray = (float*)calloc(numberOfBins,sizeof(float));
    
    //calculate STD for each bin
    int ibin;
    for(ibin=0;ibin<numberOfBins;ibin++)
    {
        [fileReader retrieveFreshAudio:tempCalculationBuffer numFrames:(UInt32)(lengthOfBin) numChannels:1];
        stdArray[ibin] = dspAnalizer->SDT(tempCalculationBuffer, lengthOfBin);
    }
    //sort array of STDs
    std::sort(stdArray, stdArray + numberOfBins, std::greater<float>());
    //take value that is greater than 40% STDs
    float sig = 2 * stdArray[(int)ceil(((float)numberOfBins)*0.4)];
    float negsig = -1* sig;
    
    //make maximal bins for faster processing
    lengthOfBin = RING_BUFFER_SIZE;
    numberOfBins = ceil((float)numberOfSamples/(float)lengthOfBin);
    
    //find peaks
    int numberOfFramesRead;
    int isample;
    
    int schmitPosState = kSchmittOFF;
    int schmitNegState = kSchmittOFF;
    float maxPeakValue = -1000.0;
    int maxPeakIndex = 0;
    float minPeakValue = 1000.0;
    int minPeakIndex = 0;
    NSMutableArray * peaksIndexes = [[NSMutableArray alloc] initWithCapacity:0];
    for(ibin=0;ibin<numberOfBins;ibin++)
    {
        numberOfFramesRead = ibin == (numberOfBins-1) ? (numberOfSamples % RING_BUFFER_SIZE):RING_BUFFER_SIZE;

        [fileReader retrieveFreshAudio:tempCalculationBuffer numFrames:(UInt32)(numberOfFramesRead) numChannels:1 seek:ibin*RING_BUFFER_SIZE];
        stdArray[ibin] = dspAnalizer->SDT(tempCalculationBuffer, numberOfFramesRead);
        
        
        for(isample=0;isample<numberOfFramesRead;isample++)
        {
            //determine state of positive schmitt trigger
            if(schmitPosState == kSchmittOFF && tempCalculationBuffer[isample]>sig)
            {
                schmitPosState =kSchmittON;
                maxPeakValue = -1000.0;
            }
            else if(schmitPosState == kSchmittON && tempCalculationBuffer[isample]<0)
            {
                schmitPosState = kSchmittOFF;
                BBSpike * tempSpike = [[BBSpike alloc] initWithValue:maxPeakValue index:maxPeakIndex andTime:((float)maxPeakIndex)/aFile.samplingrate];
                [peaksIndexes addObject:tempSpike];//add max of positive peak
                [tempSpike release];
            }
            
            //determine state of negative schmitt trigger
            if(schmitNegState == kSchmittOFF && tempCalculationBuffer[isample]<negsig)
            {
                schmitNegState =kSchmittON;
                minPeakValue = 1000.0;
            }
            else if(schmitNegState == kSchmittON && tempCalculationBuffer[isample]>0)
            {
                schmitNegState = kSchmittOFF;
                BBSpike * tempSpike = [[BBSpike alloc] initWithValue:minPeakValue index:minPeakIndex andTime:((float)minPeakIndex)/aFile.samplingrate];
                [peaksIndexes addObject:tempSpike]; //add min of negative peak
                [tempSpike release];
            }
            
            //find max in positive peak
            if(schmitPosState==kSchmittON && tempCalculationBuffer[isample]>maxPeakValue)
            {
                maxPeakValue = tempCalculationBuffer[isample];
                maxPeakIndex = isample + ibin*RING_BUFFER_SIZE;
            }
            
            //find min in negative peak
            else if(schmitNegState==kSchmittON && tempCalculationBuffer[isample]<minPeakValue)
            {
                minPeakValue = tempCalculationBuffer[isample];
                minPeakIndex = isample + ibin*RING_BUFFER_SIZE;
            }
        }
    }
    
    
    //TODO: Add kill interval
    
    
    
    aFile.spikes = peaksIndexes;
    [aFile save];
    [peaksIndexes release];
    free(stdArray);
    
    return 0;
}

-(NSMutableArray *) allSpikes
{
    if(_file)
    {
        return _file.spikes;
    }
}

- (float)currentFileTime
{
    if (fileReader) {
        return fileReader.currentTime;
    }
    
    return 0;
}

- (void)setCurrentFileTime:(float)newCurrentFileTime
{
    
    if (fileReader) {
        fileReader.currentTime = newCurrentFileTime;
    }
}

- (float)fileDuration
{
    
    if (fileReader) {
        return fileReader.duration;
    }

    return 0;
    
}

- (BBFile *) fileToAnalyze
{
    return _file;
}

@end
