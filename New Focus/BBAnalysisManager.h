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

@property float threshold1;
@property float threshold2;

- (int)findSpikes:(BBFile *)aFile;

-(void) prepareFileForSelection:(BBFile *)aFile;
- (void)fetchAudioAndSpikes:(float *)data numFrames:(UInt32)numFrames whichChannel:(UInt32)whichChannel stride:(UInt32)stride;
-(void) filterSpikes;
-(NSMutableArray *) allSpikes;
-(NSArray *) autocorrelationWithFile:(BBFile *) afile maxtime:(float) maxtime andBinsize:(float) binsize;
-(void) ISIWithFile:(BBFile *) afile maxtime:(float) maxtime numOfBins:(int) bins values:(NSMutableArray *) valuesY limits:(NSMutableArray *) limitsX;
@end
