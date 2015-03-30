//
//  BBAnalysisManager.m
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/10/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import "BBAnalysisManager.h"
#import "BBSpike.h"
#import "BBChannel.h"
#import "BBSpikeTrain.h"
#import <Accelerate/Accelerate.h>
#import <cmath>

#define BUFFER_SIZE 524288

#define kSchmittON 1
#define kSchmittOFF 2

#define AVERAGE_SPIKE_HALF_LENGTH_SECONDS 0.002
#define LENGTH_OF_STD_CIRC_ARRAY 200 //used for RT spike sorting
#define LENGTH_OF_RT_DATA_BUFFER 2048 //used for RT spike sorting
#define LENGTH_OF_PEAKS_BUFFER 2048 // used to store RT detected peaks

static BBAnalysisManager *bbAnalysisManager = nil;

@interface BBAnalysisManager ()
{
    __block BBAudioFileReader *fileReader;
    DSPAnalysis *dspAnalizer;
    float * tempCalculationBuffer;//used to load data for display while scrubbing
    BBFile * _file;
    int _currentChannel;
    int _currentTrainIndex;
    NSArray * alphabetArray;
    
    
    //RT spike sorting
    float rtKillInterval;
    float *stdCircArray;
    float *singleChannelDataBuffer;
    int headSTDCircArray;
    int rtSchmitPosState;
    int rtSchmitNegState;
    float rtMaxPeakValue;
    int rtMaxPeakIndex;
    float rtMinPeakValue;
    int rtMinPeakIndex;
    float *peaksIndexCircBuffer; //used to store index of real time detected peaks
    float *peaksValueCircBuffer; //used to store value of real time detected peaks
    int headPeaksBuffer;
    float rtSamplingRate;
    
}
@end


@implementation BBAnalysisManager

@synthesize fileToAnalyze;
@synthesize rtThresholdFirst;
@synthesize rtThresholdSecond;


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
        alphabetArray = [[NSArray arrayWithObjects:  @"a", @"b", @"c", @"d", @"e", @"f", @"g", @"h", @"i", @"j", @"k", @"l", @"m", @"n", @"o", @"p", @"q", @"r", @"s", @"t", @"u", @"v", @"w", @"x", @"y", @"z", nil] retain];
        self.rtThresholdSecond = 0.0f;
        self.rtThresholdFirst = 0.0f;
    }
    
    return self;
}

#pragma mark - Data fetch

-(void) prepareFileForSelection:(BBFile *)aFile
{
    _currentChannel = 0;
    _currentTrainIndex = 0;
    _file = aFile;
    if (fileReader != nil)
    {
        [fileReader release];
        fileReader = nil;
    }
    fileReader = [[BBAudioFileReader alloc]
                  initWithAudioFileURL:[aFile fileURL]
                  samplingRate:aFile.samplingrate
                  numChannels:aFile.numberOfChannels];

}

- (void)fetchAudioAndSpikes:(float *)data numFrames:(UInt32)numFrames stride:(UInt32)stride
{
    UInt32 targetFrame = (UInt32)(fileReader.currentTime * ((float)fileReader.samplingRate));
    int startFrame = targetFrame - numFrames;
    if(startFrame<0)
    {
        startFrame = 0;
    }
    memset(tempCalculationBuffer, 0, BUFFER_SIZE*sizeof(float));
    //real number of frames to read (we may read less if we are on begining of the file)
    int numberOfFramesToRead = targetFrame-startFrame;
    
    [fileReader retrieveFreshAudio:tempCalculationBuffer+(numFrames-numberOfFramesToRead)*_file.numberOfChannels numFrames:numberOfFramesToRead numChannels:_file.numberOfChannels seek:startFrame];
    float zero = 0.0f;
    vDSP_vsadd(&(tempCalculationBuffer[_currentChannel]),
               _file.numberOfChannels,
               &zero,
               data,
               stride,
               numFrames);
    
}


#pragma mark - Spike Analysis

-(int) findSpikes:(BBFile *)aFile
{
    _file = aFile;
    int result = 0;
    [[_file allSpikes] removeAllObjects];
    for(int i=0;i<aFile.numberOfChannels;i++)
    {
        if([self findSpikes:aFile andChannel:i]==-1)
        {
            result = -1;
        }
    }
    return result;
}


//-------------------- RT spike sorting ---------------------------------

-(float *) rtPeaksIndexs
{
    return peaksIndexCircBuffer;
}

-(float *) rtPeaksValues
{
    return peaksValueCircBuffer;
}

-(int) numberOfRTSpikes
{
    return LENGTH_OF_PEAKS_BUFFER;
}

//
// Init variables and buffers for real time spike sorting
//
-(void) initRTSpikeSorting:(float) samplingRate
{
    rtSamplingRate = samplingRate;
    rtKillInterval = 0.005f;//5ms
    stdCircArray = (float*)calloc(LENGTH_OF_STD_CIRC_ARRAY,sizeof(float));
    headSTDCircArray = 0;
    singleChannelDataBuffer = (float*)calloc(LENGTH_OF_RT_DATA_BUFFER,sizeof(float));
    
    rtSchmitPosState  = kSchmittOFF;
    rtSchmitNegState  = kSchmittOFF;
    rtMaxPeakValue  = -1000.0;
    rtMaxPeakIndex  = 0;
    rtMinPeakValue  = 1000.0;
    rtMinPeakIndex  = 0;
    
    peaksIndexCircBuffer  = (float*)calloc(LENGTH_OF_PEAKS_BUFFER,sizeof(float));
    peaksValueCircBuffer = (float*)calloc(LENGTH_OF_PEAKS_BUFFER,sizeof(float));
    headPeaksBuffer = 0;
}


-(void) stopRTSpikeSorting
{
    free(stdCircArray);
    free(singleChannelDataBuffer);
    free(peaksValueCircBuffer);
    free(peaksIndexCircBuffer);
}

-(void) clearRTSpikes
{
    memset(peaksValueCircBuffer, 0, sizeof(float)*LENGTH_OF_PEAKS_BUFFER);
    memset(peaksIndexCircBuffer, 0, sizeof(float)*LENGTH_OF_PEAKS_BUFFER);
}

//
//Process batch of data for real time spike sorting
//
-(void) findSpikesInRTForData:(float *) data numberOfFrames:(int) numberOfFramesInData numberOfChannel:(int) numOfChannels selectedChannel:(int) whichChannel
{
    //move old peaks in time (add numberOfFramesInData to their index)
    float indexOffset = (float)numberOfFramesInData;
    vDSP_vsadd(peaksIndexCircBuffer,
               1,
               &indexOffset,
               peaksIndexCircBuffer,
               1,
               LENGTH_OF_PEAKS_BUFFER);
    
    //first calculate STD of current batch of data and put it in circular STD buffer
    float zero = 0.0f;
    vDSP_vsadd((float *)&data[whichChannel],
               numOfChannels,
               &zero,
               singleChannelDataBuffer,
               1,
               numberOfFramesInData);
    stdCircArray[headSTDCircArray] = dspAnalizer->SDT(singleChannelDataBuffer, numberOfFramesInData);
    headSTDCircArray = (headSTDCircArray+1)%LENGTH_OF_STD_CIRC_ARRAY;
    
    //calculate mean STD for last LENGTH_OF_STD_CIRC_ARRAY batches
    float meanSTD = 0;
    vDSP_meanv(stdCircArray,1,&meanSTD,LENGTH_OF_STD_CIRC_ARRAY);
    float sig = meanSTD*1.5;
    float negsig = -1* sig;
    
    

    
    //find peaks
    int isample;
    

    NSMutableArray * peaksIndexes = [[NSMutableArray alloc] initWithCapacity:0];
    NSMutableArray * peaksIndexesNeg = [[NSMutableArray alloc] initWithCapacity:0];


    
    for(isample=0;isample<numberOfFramesInData;isample++)
    {
        //determine state of positive schmitt trigger
        if(rtSchmitPosState == kSchmittOFF && singleChannelDataBuffer[isample]>sig)
        {
            rtSchmitPosState =kSchmittON;
            rtMaxPeakValue = -1000.0;
        }
        else if(rtSchmitPosState == kSchmittON && singleChannelDataBuffer[isample]<0)
        {
            rtSchmitPosState = kSchmittOFF;
            BBSpike * tempSpike = [[BBSpike alloc] initWithValue:rtMaxPeakValue index:rtMaxPeakIndex andTime:((float)isample)/rtSamplingRate];
            [peaksIndexes addObject:tempSpike];//add max of positive peak
            [tempSpike release];
        }
        
        //determine state of negative schmitt trigger
        if(rtSchmitNegState == kSchmittOFF && singleChannelDataBuffer[isample]<negsig)
        {
            rtSchmitNegState =kSchmittON;
            rtMinPeakValue = 1000.0;
        }
        else if(rtSchmitNegState == kSchmittON && singleChannelDataBuffer[isample]>0)
        {
            rtSchmitNegState = kSchmittOFF;
            BBSpike * tempSpike = [[BBSpike alloc] initWithValue:rtMinPeakValue index:rtMinPeakIndex andTime:((float)isample)/rtSamplingRate];
            [peaksIndexesNeg addObject:tempSpike]; //add min of negative peak
            [tempSpike release];
        }
        
        //find max in positive peak
        if(rtSchmitPosState==kSchmittON && singleChannelDataBuffer[isample]>rtMaxPeakValue)
        {
            rtMaxPeakValue = singleChannelDataBuffer[isample];
            rtMaxPeakIndex = numberOfFramesInData - isample;
        }
        
        //find min in negative peak
        else if(rtSchmitNegState==kSchmittON && singleChannelDataBuffer[isample]<rtMinPeakValue)
        {
            rtMinPeakValue = singleChannelDataBuffer[isample];
            rtMinPeakIndex = numberOfFramesInData - isample;
        }
    }

    
    int i;
    if([peaksIndexes count]>0)
    {
        //Filter positive spikes using kill interval
        
        for(i=0;i<[peaksIndexes count]-1;i++) //look on the right
        {
            if([(BBSpike *)[peaksIndexes objectAtIndex:i] value]<[(BBSpike *)[peaksIndexes objectAtIndex:i+1] value])
            {
                if(([(BBSpike *)[peaksIndexes objectAtIndex:i+1] time]-[(BBSpike *)[peaksIndexes objectAtIndex:i] time])<rtKillInterval)
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
                if(([(BBSpike *)[peaksIndexes objectAtIndex:i] time]-[(BBSpike *)[peaksIndexes objectAtIndex:i-1] time])<rtKillInterval)
                {
                    [peaksIndexes removeObjectAtIndex:i];
                    i--;
                }
            }
        }
    }
    
    if([peaksIndexesNeg count]>0)
    {
        //Filter negative spikes using kill interval
        for(i=0;i<[peaksIndexesNeg count]-1;i++)
        {
            if([(BBSpike *)[peaksIndexesNeg objectAtIndex:i] value]>[(BBSpike *)[peaksIndexesNeg objectAtIndex:i+1] value])
            {
                if(([(BBSpike *)[peaksIndexesNeg objectAtIndex:i+1] time]-[(BBSpike *)[peaksIndexesNeg objectAtIndex:i] time])<rtKillInterval)
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
                if(([(BBSpike *)[peaksIndexesNeg objectAtIndex:i] time]-[(BBSpike *)[peaksIndexesNeg objectAtIndex:i-1] time])<rtKillInterval)
                {
                    [peaksIndexesNeg removeObjectAtIndex:i];
                    i--;
                }
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
    
    
    for(i=0;i<[sortedArray count];i++)
    {
        peaksIndexCircBuffer[headPeaksBuffer] = (float)[(BBSpike *)[sortedArray objectAtIndex:i] index];
        peaksValueCircBuffer[headPeaksBuffer] = [(BBSpike *)[sortedArray objectAtIndex:i] value];
        headPeaksBuffer = (headPeaksBuffer+1)%LENGTH_OF_PEAKS_BUFFER;
    }


    [peaksIndexes release];
    [peaksIndexesNeg release];
    [sortDescriptor release];
    [sortedArray release];
    
}
//------------------------------------------------------------------------

//
// Find spikes in one channel with index: channelIndex
// In order to work this function need data that is without offset
//(schmit triger needs that, maybe we should substract mean value or detrend)
//
- (int)findSpikes:(BBFile *)aFile andChannel:(int) channelIndex
{

    if (fileReader != nil)
    {
        [fileReader release];
        fileReader = nil;
    }

    fileReader = [[BBAudioFileReader alloc]
                  initWithAudioFileURL:[aFile fileURL]
                  samplingRate:aFile.samplingrate
                  numChannels:aFile.numberOfChannels];
    
    
    int numberOfSamples = (int)(fileReader.duration * aFile.samplingrate);
    float killInterval = 0.005;//5ms
    int numberOfBins = 200;
    int lengthOfBin = numberOfSamples/numberOfBins;
    int maxLengthOfBin = (BUFFER_SIZE/aFile.numberOfChannels);
    if(lengthOfBin>maxLengthOfBin)
    {
        lengthOfBin = maxLengthOfBin;
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
    float zero = 0.0f;
    for(ibin=0;ibin<numberOfBins;ibin++)
    {
        [fileReader retrieveFreshAudio:tempCalculationBuffer numFrames:(UInt32)(lengthOfBin) numChannels:aFile.numberOfChannels];
        //get only one channel and put it on the begining of buffer in non-interleaved form
        vDSP_vsadd((float *)&tempCalculationBuffer[channelIndex],
                   aFile.numberOfChannels,
                   &zero,
                   tempCalculationBuffer,
                   1,
                   lengthOfBin);
        stdArray[ibin] = dspAnalizer->SDT(tempCalculationBuffer, lengthOfBin);
    }
    //sort array of STDs
    std::sort(stdArray, stdArray + numberOfBins, std::greater<float>());
    //take value that is greater than 40% STDs
    float sig = 2 * stdArray[(int)ceil(((float)numberOfBins)*0.4)];
    float negsig = -1* sig;
    
    //make maximal bins for faster processing
    lengthOfBin = (BUFFER_SIZE/aFile.numberOfChannels);
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
        //read lengthOfBin frames except for last one reading where we should read only what is left
        numberOfFramesRead = ibin == (numberOfBins-1) ? (numberOfSamples % lengthOfBin):lengthOfBin;

        [fileReader retrieveFreshAudio:tempCalculationBuffer numFrames:(UInt32)(numberOfFramesRead) numChannels:aFile.numberOfChannels seek:ibin*lengthOfBin];
      
        //get only one channel and put it on the begining of buffer in non-interleaved form
        vDSP_vsadd((float *)&tempCalculationBuffer[channelIndex],
                   aFile.numberOfChannels,
                   &zero,
                   tempCalculationBuffer,
                   1,
                   lengthOfBin);
        
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
                maxPeakIndex = isample + ibin*lengthOfBin;
            }
            
            //find min in negative peak
            else if(schmitNegState==kSchmittON && tempCalculationBuffer[isample]<minPeakValue)
            {
                minPeakValue = tempCalculationBuffer[isample];
                minPeakIndex = isample + ibin*lengthOfBin;
            }
        }
    }
    
    int i;
    if([peaksIndexes count]>0)
    {
        //Filter positive spikes using kill interval
 
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
    }
    
    if([peaksIndexesNeg count]>0)
    {
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
    }
    [peaksIndexes addObjectsFromArray:peaksIndexesNeg];
    
    //sort all spikes according to time
    NSSortDescriptor *sortDescriptor;
    sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"index"
                                                 ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    NSMutableArray *sortedArray;
    sortedArray = [[peaksIndexes sortedArrayUsingDescriptors:sortDescriptors] mutableCopy];

    //add spikes
    [aFile.allSpikes addObject:sortedArray];

    
    //[aFile save];
    [peaksIndexes release];
    [peaksIndexesNeg release];
    [sortDescriptor release];
    [sortedArray release];

    free(stdArray);
    
    return 0;
}

//
// Separate all spikes to spike trains. And put it in BBSpikeTrain object
//
-(void) filterSpikes
{
    if(_file)
    {
        for(int channelIndex = 0;channelIndex<_file.numberOfChannels;channelIndex++)
        {
            BBChannel * tempChannel = [[_file allChannels] objectAtIndex:channelIndex];
            NSMutableArray * currentChannelSpikes = [[_file allSpikes] objectAtIndex:channelIndex];
            for(int spikeIndex = 0;spikeIndex<[tempChannel.spikeTrains count];spikeIndex++)
            {
                BBSpikeTrain * tempSpikeTrain = [tempChannel.spikeTrains objectAtIndex:spikeIndex];
                [tempSpikeTrain.spikes removeAllObjects];
                
                float uperThreshold;
                float lowerThreshold;
                if(tempSpikeTrain.firstThreshold>tempSpikeTrain.secondThreshold)
                {
                    uperThreshold = tempSpikeTrain.firstThreshold;
                    lowerThreshold = tempSpikeTrain.secondThreshold;
                }
                else
                {
                    uperThreshold = tempSpikeTrain.secondThreshold;
                    lowerThreshold = tempSpikeTrain.firstThreshold;
                }
                
                BBSpike * tempSpike;
                for(int i=0;i<[currentChannelSpikes count];i++)
                {
                    tempSpike = (BBSpike *)[currentChannelSpikes objectAtIndex:i];
                    if(tempSpike.value>lowerThreshold && tempSpike.value<uperThreshold)
                    {
                        [tempSpikeTrain.spikes addObject:tempSpike];
                    }
                }
            }
        
        }
        _file.spikesFiltered = FILE_SPIKE_SORTED;
        [_file save];
    }
 }

//
//Average spikes. It performs one pass calculation of everage and STD:
//http://www.strchr.com/standard_deviation_in_one_pass
//double std_dev2(double a[], int n) {
//    if(n == 0)
//        return 0.0;
//    double sum = 0;
//    double sq_sum = 0;
//    for(int i = 0; i < n; ++i) {
//        sum += a[i];
//        sq_sum += a[i] * a[i];
//    }
//    double mean = sum / n;
//    double variance = sq_sum / n - mean * mean;
//    return sqrt(variance);
//}
//
-(AverageSpikeData *) getAverageSpikesForChannel:(int) channelIndex inFile:(BBFile *) aFile
{
    if(![aFile.spikesFiltered isEqualToString:FILE_SPIKE_SORTED])
    {
        return nil;
    }
    
    if (fileReader != nil)
    {
        [fileReader release];
        fileReader = nil;
    }
    
    fileReader = [[BBAudioFileReader alloc]
                  initWithAudioFileURL:[aFile fileURL]
                  samplingRate:aFile.samplingrate
                  numChannels:aFile.numberOfChannels];
    
    
    int numberOfSamples = (int)(fileReader.duration * aFile.samplingrate);
    int lengthOfBin = (BUFFER_SIZE/aFile.numberOfChannels);
    int numberOfBins = ceil((float)numberOfSamples/(float)lengthOfBin);
    

    int numberOfFramesRead;
    int currentFrameOffset = 0;
    int ibin;
    float zero=0.0;
    NSMutableArray * spikeTrains = [(BBChannel *)[[aFile allChannels] objectAtIndex:channelIndex] spikeTrains];
    int halfSpikeLength = [aFile samplingrate] * AVERAGE_SPIKE_HALF_LENGTH_SECONDS ;
    int spikeLength = 2*halfSpikeLength+1;
    AverageSpikeData * avr = (AverageSpikeData *)calloc([spikeTrains count], sizeof(AverageSpikeData));
    

    
    BBSpikeTrain * tempSpikeTrain;
    BBSpike * tempSpike;
    int * lastSpikeTrainIndex = (int *)calloc([spikeTrains count], sizeof(int));
    //Init whole structure that contans result
    for(int i=0;i<[spikeTrains count];i++)
    {
        avr[i].averageSpike = (float *)calloc(spikeLength, sizeof(float));
        avr[i].topSTDLine = (float *)calloc(spikeLength, sizeof(float));
        avr[i].bottomSTDLine = (float *)calloc(spikeLength, sizeof(float));
        avr[i].numberOfSamplesInData = spikeLength;
        avr[i].samplingRate = [aFile samplingrate];
        avr[i].countOfSpikes = 0;
    }
    
    //Buffer used just for calculation of STD
    float * tempSqrBuffer = (float *)calloc(spikeLength, sizeof(float));
    
    //Got throungh all file and collect and summ spikes
    for(ibin=0;ibin<numberOfBins;ibin++)
    {
        //read lengthOfBin frames except for last one reading where we should read only what is left
        numberOfFramesRead = ibin == (numberOfBins-1) ? (numberOfSamples % lengthOfBin):lengthOfBin;
        currentFrameOffset = ibin*lengthOfBin;
        [fileReader retrieveFreshAudio:tempCalculationBuffer numFrames:(UInt32)(numberOfFramesRead) numChannels:aFile.numberOfChannels seek:currentFrameOffset];
        
        //get only one channel and put it on the begining of buffer in non-interleaved form
        //get new batch of samples
        vDSP_vsadd((float *)&tempCalculationBuffer[channelIndex],
                   aFile.numberOfChannels,
                   &zero,
                   tempCalculationBuffer,
                   1,
                   numberOfFramesRead);
        
        // go through all spike trains and check if we can find spikes inside current batch
        //of samples. If we find it we will add it to average buffer (averageSpike)
        for(int spikeTrainIndex = 0;spikeTrainIndex<[spikeTrains count];spikeTrainIndex++)
        {
            tempSpikeTrain = (BBSpikeTrain *)[spikeTrains objectAtIndex:spikeTrainIndex];
            for(int spikeIndex = lastSpikeTrainIndex[spikeTrainIndex];spikeIndex<[[tempSpikeTrain spikes] count];spikeIndex++)
            {
                
                tempSpike = (BBSpike *)[[tempSpikeTrain spikes] objectAtIndex:spikeIndex];
                //if our spike is outside current batch of samples go to next channel
                if((tempSpike.index+halfSpikeLength)>(currentFrameOffset+numberOfFramesRead))
                {
                    break;
                }
                   //if we have full left side of spike
                if((tempSpike.index-halfSpikeLength)>=currentFrameOffset)
                {
                    //add spike to average buffer
                    vDSP_vadd (
                               avr[spikeTrainIndex].averageSpike,
                               1,
                               &tempCalculationBuffer[tempSpike.index-halfSpikeLength-currentFrameOffset],
                               1,
                               avr[spikeTrainIndex].averageSpike,
                               1,
                               spikeLength
                               );
                    
                    avr[spikeTrainIndex].countOfSpikes++;
                    
                    //One pass STD and mean !!!
                   //Calculate squared value of vector elements
                   vDSP_vsq(
                            &tempCalculationBuffer[tempSpike.index-halfSpikeLength-currentFrameOffset],1
                                ,tempSqrBuffer
                                ,1
                                ,spikeLength);
                    
                    //add to summ of squared elements
                    vDSP_vadd (
                               avr[spikeTrainIndex].topSTDLine,
                               1,
                               tempSqrBuffer,
                               1,
                               avr[spikeTrainIndex].topSTDLine,
                               1,
                               spikeLength
                               );

                }
                //increment index of last checked spike so that we don't have to
                //check it again
                lastSpikeTrainIndex[spikeTrainIndex]++;
            }
        }
    }
    
    //divide sum of spikes with number of spikes
    //and find max and min
    for(int i=0;i<[spikeTrains count];i++)
    {
        if(avr[i].countOfSpikes>1)
        {
            float divider = (float) avr[i].countOfSpikes;
            vDSP_vsdiv (
                    avr[i].averageSpike,
                    1,
                    &divider,
                    avr[i].averageSpike,
                    1,
                    spikeLength
                    );
            
            //fined max
            vDSP_maxv(avr[i].averageSpike,
                       1,
                       &(avr[i].maxAverageSpike),
                       spikeLength
                       );
            //find min
            vDSP_minv (
                       avr[i].averageSpike,
                       1,
                       &(avr[i].minAverageSpike),
                       spikeLength
                       );
            
            //Calculate STD
            //mean of square sum
            vDSP_vsdiv (
                        avr[i].topSTDLine,
                        1,
                        &divider,
                        avr[i].topSTDLine,
                        1,
                        spikeLength
                        );
            //square of mean
            vDSP_vsq(
                     avr[i].averageSpike
                     ,1
                     ,tempSqrBuffer
                     ,1
                     ,spikeLength);
            
            //substract mean of square summ and square of mean
            //vDSP_vsub has documentation error/contradiction in order of operands
            //we will get variance
            vDSP_vsub (
                       tempSqrBuffer,
                       1,
                       avr[i].topSTDLine,
                       1,
                       tempSqrBuffer,
                       1,
                       spikeLength
                       );
            
            //calculate STD from variance
            for(int k=0;k<spikeLength;k++)
            {
                tempSqrBuffer[k] = sqrtf(tempSqrBuffer[k]);
            }
            
            //Make top line and bottom line around mean that represent one STD deviation from mean
            
            //vDSP_vsub has documentation error/contradiction in order of operands
            //bottom line
            vDSP_vsub (
                       tempSqrBuffer,
                       1,
                       avr[i].averageSpike,
                       1,
                       avr[i].bottomSTDLine,
                       1,
                       spikeLength
                       );
            
            //top line
            vDSP_vadd (
                       avr[i].averageSpike,
                       1,
                       tempSqrBuffer,
                       1,
                       avr[i].topSTDLine,
                       1,
                       spikeLength
                       );
            
            //Find max and min of top and bottom std line respectively
            //fined max
            vDSP_maxv(avr[i].topSTDLine,
                      1,
                      &(avr[i].maxStd),
                      spikeLength
                      );
            //find min
            vDSP_minv (
                       avr[i].bottomSTDLine,
                       1,
                       &(avr[i].minStd),
                       spikeLength
                       );
            
        }
    }
    
    free(tempSqrBuffer);
    return avr;
}



//
//Calculate autocorrelation for Spike Train with index aSpikeTrainIndex in channel with index aChanIndex in file afile
//binsize: is size of one bin in seconds
//maxtime: defines how far we shift the signal during correlation [-binsize*0.5, maxtime+binsize*0.5]
//
-(NSArray *) autocorrelationWithFile:(BBFile *) afile channelIndex:(NSInteger) aChanIndex spikeTrainIndex:(NSInteger) aSpikeTrainIndex maxtime:(float) maxtime andBinsize:(float) binsize
{
    NSMutableArray * spikeTrain = (NSMutableArray *)[[[[afile.allChannels objectAtIndex:aChanIndex] spikeTrains] objectAtIndex:aSpikeTrainIndex] spikes];
    if(afile && [spikeTrain count]>1)
    {
        BBSpike * firstSpike;
        BBSpike * secondSpike;
        int n = ceilf((maxtime+binsize)/binsize);
        
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
//Calculate crosscorrelation for two spike trains
//binsize: is size of one bin in seconds
//maxtime: defines how far we shift the signal during correlation in both directions[-maxtime-binsize*0.5, maxtime+binsize*0.5] (in seconds)
//
-(NSArray *) crosscorrelationWithFile:(BBFile *) afile firstChannelIndex:(NSInteger) fChanIndex firstSpikeTrainIndex:(NSInteger) fSpikeTrainIndex secondChannelIndex:(NSInteger) sChanIndex secondSpikeTrainIndex:(NSInteger) sSpikeTrainIndex maxtime:(float) maxtime andBinsize:(float) binsize
{
    NSMutableArray * fspikeTrain = (NSMutableArray *)[[[[afile.allChannels objectAtIndex:fChanIndex] spikeTrains] objectAtIndex:fSpikeTrainIndex] spikes];
    NSMutableArray * sspikeTrain = (NSMutableArray *)[[[[afile.allChannels objectAtIndex:sChanIndex] spikeTrains] objectAtIndex:sSpikeTrainIndex] spikes];
    if(afile && [fspikeTrain count]>1 && [sspikeTrain count]>1)
    {
        BBSpike * firstSpike;
        BBSpike * secondSpike;
        int n = ceilf((2*maxtime+binsize)/binsize);
        
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


//
//Calculate Inter spike interval analysis with logarithmically spaced bins (number of bins = bins) and put result
//in valuesY and limits of bins in limitsX. Limits of bins are always generated between 10^-3 and 10^1
//
-(void) ISIWithFile:(BBFile *) afile channelIndex:(NSInteger) aChannelIndex spikeTrainIndex:(NSInteger) aSpikeTrainIndex numOfBins:(int) bins values:(NSMutableArray *) valuesY limits:(NSMutableArray *) limitsX
{
    NSMutableArray * spikeTrain = (NSMutableArray *)[[[[afile.allChannels objectAtIndex:aChannelIndex] spikeTrains] objectAtIndex:aSpikeTrainIndex] spikes];
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
//From 10^min to 10^max with logBins number of values
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

//
//Add another spike train (and it's thresholds) to current channel (currentChannel)
//
-(void) addAnotherThresholds
{
    _currentTrainIndex = [[[[_file allChannels] objectAtIndex:_currentChannel] spikeTrains] count];
    NSString * nameOfSpikeTrain = [NSString stringWithFormat:@"Spike %d%@",(_currentChannel+1), [alphabetArray objectAtIndex:_currentTrainIndex] ];
    BBSpikeTrain * newSpikeTrain = [[BBSpikeTrain alloc] initWithName:nameOfSpikeTrain];
    //add spike train
    [[[[_file allChannels] objectAtIndex:_currentChannel] spikeTrains] addObject:newSpikeTrain];
    [newSpikeTrain release];
}

//
//Remove currentSpikeTrain spike train from currentChannel channel
//
-(void) removeSelectedThresholds
{
    NSMutableArray * trains = (NSMutableArray *)[[[_file allChannels] objectAtIndex:_currentChannel] spikeTrains];
    if([trains count]>_currentTrainIndex)
    {
        [trains removeObjectAtIndex:_currentTrainIndex];
    }
    
    for(int i=0;i<[trains count];i++)
    {
        NSString * nameOfSpikeTrain = [[NSString stringWithFormat:@"Spike %d%@",(_currentChannel+1), [alphabetArray objectAtIndex:_currentTrainIndex] ] copy];
        BBSpikeTrain * spikeTrain = [trains objectAtIndex:i];
        spikeTrain.nameOfTrain = nameOfSpikeTrain;
        [nameOfSpikeTrain release];
    }
    _currentTrainIndex--;
    [self moveToNextSpikeTrain];
}

#pragma mark - Getters/ Setters

//
//Move index to next spike train on same channel
//
-(NSInteger) moveToNextSpikeTrain
{
    
    _currentTrainIndex = (_currentTrainIndex+1)%([[[[_file allChannels] objectAtIndex:_currentChannel] spikeTrains] count]);
    return _currentTrainIndex;
}

//
//Set current spike train index
//
-(void) setCurrentSpikeTrain:(NSInteger) aCurrentSpikeTrain
{
    
    _currentTrainIndex = aCurrentSpikeTrain;
    
}

//
//Number of spike trains in current channel
//
-(int) numberOfSpikeTrainsOnCurrentChannel
{
    return [[[[_file allChannels] objectAtIndex:_currentChannel] spikeTrains] count];
}

//
//Cumulative number of spike trains in all channel
//
-(int) numberOfSpikeTrains
{
    return [_file numberOfSpikeTrains];
}

-(NSInteger) currentSpikeTrain
{
    return _currentTrainIndex;
}

-(NSInteger) currentChannel
{
    return _currentChannel;
}

-(void) setCurrentChannel:(NSInteger)currentChannel
{
    _currentTrainIndex = 0;
    _currentChannel = currentChannel;
}

-(void) setThresholdFirst:(float)aThresholdFirst
{
    NSMutableArray * trains = (NSMutableArray *)[[[_file allChannels] objectAtIndex:_currentChannel] spikeTrains];
    BBSpikeTrain * spikeTrain = [trains objectAtIndex:_currentTrainIndex];
    spikeTrain.firstThreshold = aThresholdFirst;
}

-(float) thresholdFirst
{
    NSMutableArray * trains = (NSMutableArray *)[[[_file allChannels] objectAtIndex:_currentChannel] spikeTrains];
    BBSpikeTrain * spikeTrain = [trains objectAtIndex:_currentTrainIndex];

    return spikeTrain.firstThreshold;
}

-(void) setThresholdSecond:(float) aThresholdSecond
{
    NSMutableArray * trains = (NSMutableArray *)[[[_file allChannels] objectAtIndex:_currentChannel] spikeTrains];
    BBSpikeTrain * spikeTrain = [trains objectAtIndex:_currentTrainIndex];
    spikeTrain.secondThreshold = aThresholdSecond;
}


-(void) solveOverlapForIndex
{
    NSMutableArray * trains = (NSMutableArray *)[[[_file allChannels] objectAtIndex:_currentChannel] spikeTrains];
    BBSpikeTrain * spikeTrain = [trains objectAtIndex:_currentTrainIndex];
    float masterHighThreshold, masterLowThreshold;
    float currentHighThreshold, currentLowThreshold;
    
    if(spikeTrain.firstThreshold>spikeTrain.secondThreshold)
    {
        masterHighThreshold = spikeTrain.firstThreshold;
        masterLowThreshold = spikeTrain.secondThreshold;
    }
    else
    {
        masterHighThreshold = spikeTrain.secondThreshold;
        masterLowThreshold = spikeTrain.firstThreshold;
    }
    
    //if interval is zero height just return
    if(masterHighThreshold == masterLowThreshold)
    {
        return;
    }
    
    int i;
    for(i=0;i<[trains count];i++)
    {
        if(i==_currentTrainIndex)
        {
            continue;
        }
        BBSpikeTrain * tempSpikeTrain = [trains objectAtIndex:i];
        if(tempSpikeTrain.firstThreshold>spikeTrain.secondThreshold)
        {
            currentHighThreshold = tempSpikeTrain.firstThreshold;
            currentLowThreshold = tempSpikeTrain.secondThreshold;
        }
        else
        {
            currentHighThreshold = tempSpikeTrain.secondThreshold;
            currentLowThreshold = tempSpikeTrain.firstThreshold;
        }
        
        
        //If master contains current spike trains
        if(currentHighThreshold<=masterHighThreshold && currentLowThreshold<=masterHighThreshold && currentHighThreshold>=masterLowThreshold && currentLowThreshold>=masterLowThreshold)
        {
            //set spike train to zero and go to next spike train
            tempSpikeTrain.firstThreshold = 0;
            tempSpikeTrain.secondThreshold = 0;
            continue;
        }
        
        //if we ovelap so that master-high is in between high and low of temp spike train
        if(currentHighThreshold>masterHighThreshold && currentLowThreshold<masterHighThreshold)
        {
            //set spike train to zero and go to next spike train
            if(currentLowThreshold == tempSpikeTrain.firstThreshold)
            {
                tempSpikeTrain.firstThreshold = masterHighThreshold;
            }
            else
            {
                tempSpikeTrain.secondThreshold = masterHighThreshold;
            }
            continue;
        }
        
        
        //if we ovelap so that master-low is in between high and low of temp spike train
        if(currentHighThreshold>masterLowThreshold && currentLowThreshold<masterLowThreshold)
        {
            //set spike train to zero and go to next spike train
            if(currentHighThreshold == tempSpikeTrain.firstThreshold)
            {
                tempSpikeTrain.firstThreshold = masterLowThreshold;
            }
            else
            {
                tempSpikeTrain.secondThreshold = masterLowThreshold;
            }
            continue;
        }
    }
}


-(float) thresholdSecond
{
    NSMutableArray * trains = (NSMutableArray *)[[[_file allChannels] objectAtIndex:_currentChannel] spikeTrains];
    BBSpikeTrain * spikeTrain = [trains objectAtIndex:_currentTrainIndex];
    
    return spikeTrain.secondThreshold;
}

-(NSMutableArray *) allSpikes
{
    return [_file.allSpikes objectAtIndex:_currentChannel];
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
