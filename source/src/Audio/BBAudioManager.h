//
//  BBAudioManager.h
//  New Focus
//
//  Created by Alex Wiltschko on 7/4/12.
//  Copyright (c) 2012 Datta Lab, Harvard University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Novocaine.h"
#import "RingBuffer.h"
#import "BBAudioFileWriter.h"
#import "BBAudioFileReader.h"
#import "DSPThreshold.h"
#import "DSPAnalysis.h"
#import "NVDSP.h"
#import "NVHighpassFilter.h"
#import "NVLowpassFilter.h"
#import "NVNotchFilter.h"
#import "DemoProtocol.h"

#define RESETUP_SCREEN_NOTIFICATION @"resetupScreenNotification"
#define FILTER_PARAMETERS_CHANGED @"filterParametersChanged"
#define MAX_NUMBER_OF_FFT_SEC 6.0f

#define AM_CARRIER_FREQUENCY 5000.0
#define AM_DEMODULATION_CUTOFF 500.0

#define FILTER_SETTINGS_RAW 0
#define FILTER_SETTINGS_EKG 1
#define FILTER_SETTINGS_EEG 2
#define FILTER_SETTINGS_PLANT 3
#define FILTER_SETTINGS_CUSTOM 4

#define FILTER_LP_OFF 10000000
#define FILTER_HP_OFF 0

@class BBFile;


@interface BBAudioManager : NSObject
{

    
    UInt32 numPointsToSavePerThreshold;
    UInt32 numTriggersInThresholdHistory;

    
    BOOL recording;
    BOOL stimulating;
    BOOL thresholding;
    BOOL selecting;
    BOOL playing;
    
    //Filtering
    NVHighpassFilter * HPFilter;
    NVLowpassFilter * LPFilter;
    NVNotchFilter * NotchFilter;
    BOOL notchIsOn;
    
    
    NVNotchFilter * amDetectionNotchFilter;
    NVLowpassFilter * amDetectionLPFilter;
    NVLowpassFilter * filterAMStage1;
    NVLowpassFilter * filterAMStage2;
    NVLowpassFilter * filterAMStage3;
    

    float amDCLevelRemovalCh1;
    float amDCLevelRemovalCh2;
    float rmsOfOriginalSignal;
    float rmsOfNotchedSignal;
    
    int lpFilterCutoff;
    int hpFilterCutoff;
    
    bool playEKGBeep;
    int counterForEKGBeep;
    
}

@property (getter=samplingRate, readonly) float samplingRate;
@property (getter=numberOfChannels, readonly) int numberOfChannels;

@property (getter=sourceSamplingRate, readonly) float sourceSamplingRate;
@property (getter=sourceNumberOfChannels, readonly) int sourceNumberOfChannels;

@property UInt32 numTriggersInThresholdHistory;

@property float threshold;
@property BBThresholdType thresholdDirection;
-(BOOL) isThresholdTriggered;


@property (readonly) float rmsOfSelection;

@property float currentFileTime;
@property (readonly) float fileDuration;

@property float amOffset;
//Basic stats properties
@property float currSTD;
@property float currMax;
@property float currMin;
@property float currMean;

//States of manager
@property (readonly) BOOL recording;
@property BOOL stimulating;
@property (readonly) BOOL thresholding;
@property (readonly) BOOL selecting;
@property (readonly) BOOL playing;
@property (readonly) BOOL btOn;
@property (readonly) BOOL externalAccessoryOn;
@property (readonly) BOOL FFTOn;
@property (readonly) BOOL ECGOn;
@property (readonly) BOOL rtSpikeSorting;
@property BOOL seeking;
@property BOOL amDemodulationIsON;

@property int currentFilterSettings;

-(int) getLPFilterCutoff;
-(int) getHPFilterCutoff; 

+ (BBAudioManager *) bbAudioManager;
-(void) quitAllFunctions;
- (void)startMonitoring;

- (void)startRecording:(NSURL *)urlToFile;
- (void)stopRecording;
- (void)startThresholding:(UInt32)newNumPointsToSavePerThreshold;
- (void)stopThresholding;
- (void)startPlaying:(BBFile *) fileToPlay;
- (void)stopPlaying;
- (void)pausePlaying;
- (void)resumePlaying;
- (float)fetchAudio:(float *)data numFrames:(UInt32)numFrames whichChannel:(UInt32)whichChannel stride:(UInt32)stride;
- (float)fetchAudioForSelectedChannel:(float *)data numFrames:(UInt32)numFrames stride:(UInt32)stride;
- (NSMutableArray *) getChannels;

//Selection
-(void) endSelection;
-(void) updateSelection:(float) newSelectionTime timeSpan:(float) timeSpan;
- (float) selectionStartTime;
- (float) selectionEndTime;
- (NSMutableArray *) spikesCount;

-(NSMutableArray *) getSpikes;
-(float) getTimeForSpikes;
- (void)saveSettingsToUserDefaults;
-(void) clearWaveform;

-(void) setSeekTime:(float) newTime;



//Bluetooth
-(void) switchToBluetoothWithChannels:(int) channelConfiguration andSampleRate:(int) inSampleRate;
-(void) closeBluetooth;
-(void) selectChannel:(int) selectedChannel;
-(int) numberOfFramesBuffered;


//Mfi
-(void) switchToExternalDeviceWithChannels:(int)numberOfChannels andSampleRate:(int) inSampleRate;
-(void) closeExternalDevice;
-(void) addNewData:(float*)data frames:(int) numberOfFrames channels:(int) numberOfChannels;



//FFT
-(float **) getDynamicFFTResult;
-(UInt32) lengthOfFFTData;
-(UInt32) lengthOf30HzData;
-(void) stopFFT;
-(void) startDynanimcFFTForLiveView;
-(void) startDynanimcFFTForRecording:(BBFile *) newFile;
-(UInt32) indexOfFFTGraphBuffer;
-(UInt32) lenghtOfFFTGraphBuffer;



//RT Spike Sorting
-(void) startRTSpikeSorting;
-(void) stopRTSpikeSorting;
-(float *) rtSpikeValues;
-(float *) rtSpikeIndexes;
-(int) numberOfRTSpikes;


@property float rtThresholdFirst;
@property float rtThresholdSecond;

//ECG
-(float) heartRate;
@property (readonly) BOOL heartBeatPresent;

@property float maxVoltageVisible;

-(void) setFilterSettings:(int) newFilterSettings;

-(void) setFilterLPCutoff:(int) newLPCuttof hpCutoff:(int)newHPCutoff;

@end
