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
#import <cmath>

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


#pragma mark - Spike Analysis

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
    
    //sort all spikes according to time
    NSSortDescriptor *sortDescriptor;
    sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"index"
                                                 ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    NSMutableArray *sortedArray;
    sortedArray = [[peaksIndexes sortedArrayUsingDescriptors:sortDescriptors] mutableCopy];

    //make array of arrays (with just one element that is spike train that contains all spikes)
    NSMutableArray * spikesArray = [[NSMutableArray alloc] init];
    [spikesArray addObject:sortedArray];
    aFile.spikes = spikesArray;
    
    //aFile.analyzed = YES;
    //[aFile save];
    [peaksIndexes release];
    [peaksIndexesNeg release];
    [sortDescriptor release];
    [sortedArray release];
    [spikesArray release];
    free(stdArray);
    
    return 0;
}

//
// Separate all spikes to spike trains. And put it in _file.spikes array of spike trains
//
-(void) filterSpikes
{
    if(_file && _file.numberOfThresholds>0)
    {
        NSMutableArray * tempAllSpikes = [[NSMutableArray alloc] init];
        [tempAllSpikes addObjectsFromArray:[_file.spikes objectAtIndex:0]];
        [_file.spikes removeAllObjects];
        NSMutableArray * filteredSpikes = [[NSMutableArray alloc] initWithCapacity:0];
        for(int j=0;j<_file.numberOfThresholds;j++)
        {

            float uperThreshold;
            float lowerThreshold;
            [self setCurrentSpikeTrain:j];
            if(self.thresholdFirst>self.thresholdSecond)
            {
                uperThreshold = self.thresholdFirst;
                lowerThreshold = self.thresholdSecond;
            }
            else
            {
                uperThreshold = self.thresholdSecond;
                lowerThreshold = self.thresholdFirst;
            }
            
            int i;

            BBSpike * tempSpike;
            for(i=0;i<[tempAllSpikes count];i++)
            {
                tempSpike = (BBSpike *)[tempAllSpikes objectAtIndex:i];
                if(tempSpike.value>lowerThreshold && tempSpike.value<uperThreshold)
                {
                    [filteredSpikes addObject:tempSpike];
                }
            }
            [_file.spikes addObject:[[filteredSpikes copy] autorelease]];//put new spike train to array of trains

            [filteredSpikes removeAllObjects];
        }
        [filteredSpikes removeAllObjects];
        [filteredSpikes release];
        [tempAllSpikes removeAllObjects];
        [tempAllSpikes release];
        _file.spikesFiltered = @"filtered";
        [_file save];
    }

}

//
// Calculate autocorrelation of spike train
//
-(NSArray *) autocorrelationWithFile:(BBFile *) afile spikeTrainIndex:(NSInteger) aSpikeTrainIndex maxtime:(float) maxtime andBinsize:(float) binsize
{
    NSMutableArray * spikeTrain = (NSMutableArray *)[afile.spikes objectAtIndex:aSpikeTrainIndex];
    if(afile && [spikeTrain count]>1)
    {
        BBSpike * firstSpike;
        BBSpike * secondSpike;
        int n = ceilf((maxtime+binsize)/binsize);
        
        //float C1 =[(BBSpike *)[afile.spikes objectAtIndex:[afile.spikes count]-1] time] - [(BBSpike *)[afile.spikes objectAtIndex:0] time];
       // float C2= ((float)([afile.spikes count]*[afile.spikes count]*binsize))/C1*C1;
        
        int histogram [n];
        for (int x = 0; x < n; ++x)
        {
            histogram[x] = 0;
        }
        
        float minEdge = -binsize*0.5;
        float maxEdge = maxtime+binsize*0.5;
        float diff;
        int index;
        int mainIndex;
        int secIndex;

        for(mainIndex=0;mainIndex<[spikeTrain count]; mainIndex++)
        {
            firstSpike = [spikeTrain objectAtIndex:mainIndex];
            //Check on left of spike
            for(secIndex = mainIndex;secIndex>=0;secIndex--)
            {
                secondSpike = [spikeTrain objectAtIndex:secIndex];
                diff = firstSpike.time-secondSpike.time;
                if(diff>minEdge && diff<maxEdge)
                {
                    index = (int)(((diff-minEdge)/binsize));
                    histogram[index]++;
                }
                else
                {
                    break;
                }
            }
            //check on right of spike
            for(secIndex = mainIndex+1;secIndex<[spikeTrain count];secIndex++)
            {
                secondSpike = [spikeTrain objectAtIndex:secIndex];
                diff = firstSpike.time-secondSpike.time;
                if(diff>minEdge && diff<maxEdge)
                {
                    index = (int)(((diff-minEdge)/binsize));
                    histogram[index]++;
                }
                else
                {
                    break;
                }
            }
        }
        
        //Normalization
       // for(int i=0;i<n;i++)
       // {
       //     histogram[i] = histogram[i]/C1 - C2;
       // }
        
        NSMutableArray* histMA = [NSMutableArray arrayWithCapacity:n];
        for ( int i = 0; i < n; ++i )
        {
            [histMA addObject:[NSNumber numberWithInt:histogram[i]]];
        }
        
        
        return (NSArray *) histMA;
    }
    return nil;
}

//
// Calculate cross-correlation of two spike trains
//
-(NSArray *) crosscorrelationWithFile:(BBFile *) afile firstSpikeTrainIndex:(NSInteger) fSpikeTrainIndex secondSpikeTrainIndex:(NSInteger) sSpikeTrainIndex maxtime:(float) maxtime andBinsize:(float) binsize
{
    NSMutableArray * fspikeTrain = (NSMutableArray *)[afile.spikes objectAtIndex:fSpikeTrainIndex];
    NSMutableArray * sspikeTrain = (NSMutableArray *)[afile.spikes objectAtIndex:sSpikeTrainIndex];
    if(afile && [fspikeTrain count]>1 && [sspikeTrain count]>1)
    {
        BBSpike * firstSpike;
        BBSpike * secondSpike;
        int n = ceilf((2*maxtime+binsize)/binsize);
        
        //float C1 =[(BBSpike *)[afile.spikes objectAtIndex:[afile.spikes count]-1] time] - [(BBSpike *)[afile.spikes objectAtIndex:0] time];
        // float C2= ((float)([afile.spikes count]*[afile.spikes count]*binsize))/C1*C1;
        
        int histogram [n];
        for (int x = 0; x < n; ++x)
        {
            histogram[x] = 0;
        }
        
        float minEdge = -maxtime-binsize*0.5;
        float maxEdge = maxtime+binsize*0.5;
        float diff;
        int index;
        int mainIndex;
        int secIndex;
        BOOL insideInterval = NO;
        //go through first spike train
        for(mainIndex=0;mainIndex<[fspikeTrain count]; mainIndex++)
        {
            firstSpike = [fspikeTrain objectAtIndex:mainIndex];
            //Check on left of spike
            insideInterval = NO;
            //go through second spike train
            for(secIndex = 0;secIndex<[sspikeTrain count];secIndex++)
            {
                secondSpike = [sspikeTrain objectAtIndex:secIndex];
                diff = firstSpike.time-secondSpike.time;
                if(diff>minEdge && diff<maxEdge)
                {
                    insideInterval = YES;
                    index = (int)(((diff-minEdge)/binsize));
                    histogram[index]++;
                }
                else if(insideInterval)
                {//we pass last spike that is in interval of interest
                    break;
                }
            }
        }
        
        NSMutableArray* histMA = [NSMutableArray arrayWithCapacity:n];
        for ( int i = 0; i < n; ++i )
        {
            [histMA addObject:[NSNumber numberWithInt:histogram[i]]];
        }
        
        
        return (NSArray *) histMA;
    }
    return nil;
}



//Inter-spike-interval histogram generator
-(void) ISIWithFile:(BBFile *) afile spikeTrainIndex:(NSInteger) aSpikeTrainIndex maxtime:(float) maxtime numOfBins:(int) bins values:(NSMutableArray *) valuesY limits:(NSMutableArray *) limitsX
{
    NSMutableArray * spikeTrain = (NSMutableArray *)[afile.spikes objectAtIndex:aSpikeTrainIndex];
    if(afile && [spikeTrain count]>1)
    {
        int spikesCount = [spikeTrain count];
        //make edges
        float * logspace = [self generateLogSpaceWithMin:-3 max:1 bins:bins-1];

        int histogram [bins];
        for (int x = 0; x < bins; ++x)
        {
            histogram[x] = 0;
        }
        
        //calculate histogram
        float interspikeDistance;
        for(int i=1;i<spikesCount;i++)
        {
            interspikeDistance = [((BBSpike *)[spikeTrain objectAtIndex:i]) time] - [((BBSpike *)[spikeTrain objectAtIndex:i-1]) time];
            for(int j=1;j<bins;j++)
            {
                if(interspikeDistance>logspace[j-1] && interspikeDistance<logspace[j])
                {
                    histogram[j-1]++;
                    break;
                }
            }
        }
        //Convert histogram to NSArray
        [valuesY removeAllObjects];
        [limitsX removeAllObjects];
        for ( int i = 0; i < bins; ++i )
        {
            [valuesY addObject:[NSNumber numberWithInt:histogram[i]]];
        }
        for ( int i = 0; i < bins; ++i )
        {
            [limitsX addObject:[NSNumber numberWithFloat:logspace[i]]];
        }
        free(logspace);
    }
}

//Generate logarithmically spaced vectors
-(float *) generateLogSpaceWithMin:(int) min max:(int) max bins:(int) logBins
{
    double logarithmicBase = M_E;
    double mins = pow(10.0,min);
    double maxs = pow(10.0,max);
    double logMin = log(mins);
    double logMax = log(maxs);
    double delta = (logMax - logMin) / logBins;

    double accDelta = 0;
    float* v = new float[logBins+1];
    for (int i = 0; i <= logBins; ++i)
    {
        v[i] = (float) pow(logarithmicBase, logMin + accDelta);
        accDelta += delta;// accDelta = delta * i
    }
    return v;
}

#pragma mark - Thresholds
-(void) addAnotherThresholds
{
    [_file addAnotherThresholds];
}

-(void) removeSelectedThresholds
{
    [_file removeCurrentThresholds];
}

#pragma mark - Getters/ Setters

-(NSInteger) moveToNextSpikeTrain
{
    return [_file moveToNextSpikeTrain];
}

-(void) setCurrentSpikeTrain:(NSInteger) aCurrentSpikeTrain
{
    
    _file.currentSpikeTrain = aCurrentSpikeTrain;
    
}

-(NSInteger) numberOfSpikeTrains
{
    return _file.numberOfThresholds;
}

-(NSInteger) currentSpikeTrain
{
    return _file.currentSpikeTrain;
}

-(void) setThresholdFirst:(float)aThresholdFirst
{
    _file.thresholdFirst = aThresholdFirst;
}

-(float) thresholdFirst
{
    return _file.thresholdFirst;
}

-(void) setThresholdSecond:(float) aThresholdSecond
{
    _file.thresholdSecond = aThresholdSecond;
}

-(float) thresholdSecond
{
    return _file.thresholdSecond;
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
