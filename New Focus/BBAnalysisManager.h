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
{
    NSInteger _currentSpikeTrain;
}

+ (BBAnalysisManager *) bbAnalysisManager;

@property (getter=fileToAnalyze, readonly) BBFile * fileToAnalyze;
@property float currentFileTime;
@property (readonly) float fileDuration;

@property (nonatomic) NSInteger currentSpikeTrain;
@property (nonatomic) float thresholdFirst;
@property (nonatomic) float thresholdSecond;

- (int)findSpikes:(BBFile *)aFile;

-(void) prepareFileForSelection:(BBFile *)aFile;
- (void)fetchAudioAndSpikes:(float *)data numFrames:(UInt32)numFrames whichChannel:(UInt32)whichChannel stride:(UInt32)stride;
-(void) filterSpikes;
-(NSMutableArray *) allSpikes;
-(NSArray *) autocorrelationWithFile:(BBFile *) afile spikeTrainIndex:(NSInteger) aSpikeTrainIndex maxtime:(float) maxtime andBinsize:(float) binsize;
-(void) ISIWithFile:(BBFile *) afile spikeTrainIndex:(NSInteger) aSpikeTrainIndex maxtime:(float) maxtime numOfBins:(int) bins values:(NSMutableArray *) valuesY limits:(NSMutableArray *) limitsX;
-(NSArray *) crosscorrelationWithFile:(BBFile *) afile firstSpikeTrainIndex:(NSInteger) fSpikeTrainIndex secondSpikeTrainIndex:(NSInteger) sSpikeTrainIndex maxtime:(float) maxtime andBinsize:(float) binsize;
-(NSInteger) moveToNextSpikeTrain;
-(NSInteger) numberOfSpikeTrains;
-(void) addAnotherThresholds;
-(void) removeSelectedThresholds;
@end
