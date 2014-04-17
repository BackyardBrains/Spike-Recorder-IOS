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
#define BUFFER_SIZE 524288

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

        tempCalculationBuffer = (float *)calloc(BUFFER_SIZE, sizeof(float));
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
    self.threshold1 = _file.threshold1;
    self.threshold2 = _file.threshold2;
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
    memset(tempCalculationBuffer, 0, BUFFER_SIZE*sizeof(float));
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
    float killInterval = 0.005;//5ms
    int numberOfBins = 200;
    int lengthOfBin = numberOfSamples/numberOfBins;

    if(lengthOfBin>BUFFER_SIZE)
    {
        lengthOfBin = BUFFER_SIZE;
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
    lengthOfBin = BUFFER_SIZE;
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
    NSMutableArray * peaksIndexesNeg = [[NSMutableArray alloc] initWithCapacity:0];
    for(ibin=0;ibin<numberOfBins;ibin++)
    {
        numberOfFramesRead = ibin == (numberOfBins-1) ? (numberOfSamples % BUFFER_SIZE):BUFFER_SIZE;

        [fileReader retrieveFreshAudio:tempCalculationBuffer numFrames:(UInt32)(numberOfFramesRead) numChannels:1 seek:ibin*BUFFER_SIZE];
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
                [peaksIndexesNeg addObject:tempSpike]; //add min of negative peak
                [tempSpike release];
            }
            
            //find max in positive peak
            if(schmitPosState==kSchmittON && tempCalculationBuffer[isample]>maxPeakValue)
            {
                maxPeakValue = tempCalculationBuffer[isample];
                maxPeakIndex = isample + ibin*BUFFER_SIZE;
            }
            
            //find min in negative peak
            else if(schmitNegState==kSchmittON && tempCalculationBuffer[isample]<minPeakValue)
            {
                minPeakValue = tempCalculationBuffer[isample];
                minPeakIndex = isample + ibin*BUFFER_SIZE;
            }
        }
    }
    
    
    //Filter positive spikes using kill interval
    int i;
    for(i=0;i<[peaksIndexes count]-1;i++) //look on the right
    {
        if([(BBSpike *)[peaksIndexes objectAtIndex:i] value]<[(BBSpike *)[peaksIndexes objectAtIndex:i+1] value])
        {
            if(([(BBSpike *)[peaksIndexes objectAtIndex:i+1] time]-[(BBSpike *)[peaksIndexes objectAtIndex:i] time])<killInterval)
            {
                [peaksIndexes removeObjectAtIndex:i];
                i--;
            }
        }
    }
    
    for(i=1;i<[peaksIndexes count];i++) //look on the left neighbor
    {
        if([(BBSpike *)[peaksIndexes objectAtIndex:i] value]<[(BBSpike *)[peaksIndexes objectAtIndex:i-1] value])
        {
            if(([(BBSpike *)[peaksIndexes objectAtIndex:i] time]-[(BBSpike *)[peaksIndexes objectAtIndex:i-1] time])<killInterval)
            {
                [peaksIndexes removeObjectAtIndex:i];
                i--;
            }
        }
    }
    
    //Filter negative spikes using kill interval
    for(i=0;i<[peaksIndexesNeg count]-1;i++)
    {
        if([(BBSpike *)[peaksIndexesNeg objectAtIndex:i] value]>[(BBSpike *)[peaksIndexesNeg objectAtIndex:i+1] value])
        {
            if(([(BBSpike *)[peaksIndexesNeg objectAtIndex:i+1] time]-[(BBSpike *)[peaksIndexesNeg objectAtIndex:i] time])<killInterval)
            {
                [peaksIndexesNeg removeObjectAtIndex:i];
                i--;
            }
        }
    }
    
    for(i=1;i<[peaksIndexesNeg count];i++)
    {
        if([(BBSpike *)[peaksIndexesNeg objectAtIndex:i] value]>[(BBSpike *)[peaksIndexesNeg objectAtIndex:i-1] value])
        {
            if(([(BBSpike *)[peaksIndexesNeg objectAtIndex:i] time]-[(BBSpike *)[peaksIndexesNeg objectAtIndex:i-1] time])<killInterval)
            {
                [peaksIndexesNeg removeObjectAtIndex:i];
                i--;
            }
        }
    }
    [peaksIndexes addObjectsFromArray:peaksIndexesNeg];
    
    NSSortDescriptor *sortDescriptor;
    sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"index"
                                                 ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    NSMutableArray *sortedArray;
    sortedArray = [[peaksIndexes sortedArrayUsingDescriptors:sortDescriptors] mutableCopy];

    aFile.spikes = sortedArray;
    //aFile.analyzed = YES;
    //[aFile save];
    [peaksIndexes release];
    [peaksIndexesNeg release];
    [sortDescriptor release];
    [sortedArray release];
    free(stdArray);
    
    return 0;
}

-(void) filterSpikes
{
    if(_file)
    {
        _file.threshold1 = self.threshold1;
        _file.threshold2 = self.threshold2;
        float uperThreshold;
        float lowerThreshold;
        
        if(self.threshold1>self.threshold2)
        {
            uperThreshold = self.threshold1;
            lowerThreshold = self.threshold2;
        }
        else
        {
            uperThreshold = self.threshold2;
            lowerThreshold = self.threshold1;
        }
        
        int i;
        [_file.filteredSpikes removeAllObjects];
        BBSpike * tempSpike;
        for(i=0;i<[_file.spikes count];i++)
        {
            tempSpike = (BBSpike *)[_file.spikes objectAtIndex:i];
            if(tempSpike.value>lowerThreshold && tempSpike.value<uperThreshold)
            {
                [_file.filteredSpikes addObject:tempSpike];
            }
        }
        _file.spikes = _file.filteredSpikes;

        [_file.filteredSpikes removeAllObjects];
        _file.spikesFiltered = YES;
        [_file save];
    }
}


-(NSMutableArray *) allSpikes
{
    if(_file)
    {
        return _file.spikes;
    }
    return nil;
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
