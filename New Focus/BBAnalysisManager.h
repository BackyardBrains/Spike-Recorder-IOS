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

@interface BBAnalysisManager : NSObject

+ (BBAnalysisManager *) bbAnalysisManager;

@property (getter=fileToAnalyze, readonly) BBFile * fileToAnalyze;
@property float currentFileTime;
@property (readonly) float fileDuration;

@property (nonatomic) NSInteger currentSpikeTrain;
@property (nonatomic) NSInteger currentChannel;
@property (nonatomic) float thresholdFirst;
@property (nonatomic) float thresholdSecond;

- (void)findSpikes:(BBFile *)aFile;
-(NSMutableArray *) allSpikes;
-(void) prepareFileForSelection:(BBFile *)aFile;
- (void)fetchAudioAndSpikes:(float *)data numFrames:(UInt32)numFrames stride:(UInt32)stride;
-(void) filterSpikes;

-(NSArray *) autocorrelationWithFile:(BBFile *) afile channelIndex:(NSInteger) aChanIndex spikeTrainIndex:(NSInteger) aSpikeTrainIndex maxtime:(float) maxtime andBinsize:(float) binsize;

-(NSArray *) crosscorrelationWithFile:(BBFile *) afile firstChannelIndex:(NSInteger) fChanIndex firstSpikeTrainIndex:(NSInteger) fSpikeTrainIndex secondChannelIndex:(NSInteger) sChanIndex secondSpikeTrainIndex:(NSInteger) sSpikeTrainIndex maxtime:(float) maxtime andBinsize:(float) binsize;

-(void) ISIWithFile:(BBFile *) afile channelIndex:(NSInteger) aChannelIndex spikeTrainIndex:(NSInteger) aSpikeTrainIndex maxtime:(float) maxtime numOfBins:(int) bins values:(NSMutableArray *) valuesY limits:(NSMutableArray *) limitsX;


-(NSInteger) moveToNextSpikeTrain;
-(int) numberOfSpikeTrains;
-(int) numberOfSpikeTrainsOnCurrentChannel;
-(void) addAnotherThresholds;
-(void) removeSelectedThresholds;
@end
