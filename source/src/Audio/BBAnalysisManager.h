//
//  BBAnalysisManager.h
//  Backyard Brains
//
//  Created by Stanislav Mircic on 4/10/14.
//  Copyright (c) 2014 Datta Lab, Harvard University. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BBAudioFileReader.h"
#import "DSPAnalysis.h"
#import "BBFile.h"


typedef struct _averageSpikeData {
	
	float * averageSpike;//Main line
    float graphOffset;
    float maxAverageSpike;
    float minAverageSpike;
    float * topSTDLine;
    float * bottomSTDLine;
    float maxStd;
    float minStd;
    UInt32 numberOfSamplesInData;
    float samplingRate;
    UInt32 countOfSpikes;
    /*PolyLine2f ** allSpikes;
     float maxAllSpikes;
     float minAllSpikes;*/
} AverageSpikeData;

@interface BBAnalysisManager : NSObject

+ (BBAnalysisManager *) bbAnalysisManager;

@property (getter=fileToAnalyze, readonly) BBFile * fileToAnalyze;
@property float currentFileTime;
@property (readonly) float fileDuration;

@property (nonatomic) NSInteger currentSpikeTrain;
@property (nonatomic) NSInteger currentChannel;
@property (nonatomic) float thresholdFirst;
@property (nonatomic) float thresholdSecond;

- (int)findSpikes:(BBFile *)aFile;
-(NSMutableArray *) allSpikes;
-(void) prepareFileForSelection:(BBFile *)aFile;
- (void)fetchAudioAndSpikes:(float *)data numFrames:(UInt32)numFrames stride:(UInt32)stride;
-(void) filterSpikes;

//Calculate autocorrelation for Spike Train with index aSpikeTrainIndex in channel with index aChanIndex in file afile
//binsize: is size of one bin in seconds
//maxtime: defines how far we shift the signal during correlation [-binsize*0.5, maxtime+binsize*0.5] (in seconds)
-(NSArray *) autocorrelationWithFile:(BBFile *) afile channelIndex:(NSInteger) aChanIndex spikeTrainIndex:(NSInteger) aSpikeTrainIndex maxtime:(float) maxtime andBinsize:(float) binsize;

//Calculate crosscorrelation for two spike trains
//binsize: is size of one bin in seconds
//maxtime: defines how far we shift the signal during correlation in both directions[-maxtime-binsize*0.5, maxtime+binsize*0.5] (in seconds)
-(NSArray *) crosscorrelationWithFile:(BBFile *) afile firstChannelIndex:(NSInteger) fChanIndex firstSpikeTrainIndex:(NSInteger) fSpikeTrainIndex secondChannelIndex:(NSInteger) sChanIndex secondSpikeTrainIndex:(NSInteger) sSpikeTrainIndex maxtime:(float) maxtime andBinsize:(float) binsize;


//Calculate Inter spike interval analysis with logarithmically spaced bins (number of bins = bins) and put result
//in valuesY and limits of bins in limitsX. Limits of bins are always generated between 10^-3 and 10^1
-(void) ISIWithFile:(BBFile *) afile channelIndex:(NSInteger) aChannelIndex spikeTrainIndex:(NSInteger) aSpikeTrainIndex numOfBins:(int) bins values:(NSMutableArray *) valuesY limits:(NSMutableArray *) limitsX;

-(AverageSpikeData *) getAverageSpikesForChannel:(int) channelIndex inFile:(BBFile *) aFile;

//Move index to next spike train on same channel
-(NSInteger) moveToNextSpikeTrain;
//Cumulative number of spike trains in all channel
-(int) numberOfSpikeTrains;
//Number of spike trains in current channel
-(int) numberOfSpikeTrainsOnCurrentChannel;
//Add another spike train (and it's thresholds) to current channel (currentChannel)
-(void) addAnotherThresholds;
//Remove currentSpikeTrain spike train from currentChannel channel
-(void) removeSelectedThresholds;
//Change threshold's limits so that we don't have overlapping
-(void) solveOverlapForIndex;


//RT spike sorting
-(void) initRTSpikeSorting:(float) samplingRate;
-(void) stopRTSpikeSorting;
-(void) findSpikesInRTForData:(float *) data numberOfFrames:(int) numberOfFramesInData numberOfChannel:(int) numOfChannels selectedChannel:(int) whichChannel;
-(float *) rtPeaksIndexs;
-(float *) rtPeaksValues;
-(int) numberOfRTSpikes;
@property float rtThreshold;

@end
