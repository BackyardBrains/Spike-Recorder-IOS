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
#import "InputDevice.h"
#import "ChannelConfig.h"

#define RESETUP_SCREEN_NOTIFICATION @"resetupScreenNotification"
#define CAN_NOT_FIND_CONFIG_FOR_DEVICE @"canNotFindConfigForDevice"
#define NEW_DEVICE_ACTIVATED @"newDeviceActivated"
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

#define MAX_VOLTAGE_NOT_SET -1

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
    NSMutableArray * hpFilters;
    NSMutableArray * lpFilters;
    NSMutableArray * notchFilters;
    
    BOOL notch50HzIsOn;
    BOOL notch60HzIsOn;
    
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
    
    UInt64 _preciseVirtualTimeNumOfFrames;
    
}


@property (getter=sourceSamplingRate, readonly) float sourceSamplingRate;
-(int) numberOfSourceChannels;
-(int) numberOfActiveChannels;

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
@property (readonly) BOOL FFTOn;
@property (readonly) BOOL ECGOn;
@property (readonly) BOOL rtSpikeSorting;
@property BOOL seeking;
@property BOOL amDemodulationIsON;
@property NSMutableArray* availableInputDevices;
@property int currentFilterSettings;

-(int) getLPFilterCutoff;
-(int) getHPFilterCutoff;
-(BOOL) isNotchON;
-(BOOL) is60HzNotchON;
-(BOOL) is50HzNotchON;
-(void) turnON60HzNotch;
-(void) turnON50HzNotch;
-(void) turnOFFNotchFilters;

+ (BBAudioManager *) bbAudioManager;
-(void) quitAllFunctions;
//- (void)startMonitoring;

- (void)startRecording:(BBFile *) aFile;
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
- (NSMutableArray *) getEvents;

//Selection
-(void) endSelection;
-(void) updateSelection:(float) newSelectionTime timeSpan:(float) timeSpan;
- (float) selectionStartTime;
- (float) selectionEndTime;
- (NSMutableArray *) spikesCount;

-(NSMutableArray *) getSpikes;
-(float) getVirtualTime;
- (void)saveSettingsToUserDefaults;
-(void) clearWaveform;

-(void) setSeekTime:(float) newTime;

//Input device connect/disconnect
-(int) indexOfCurrentlyActiveDevice;
-(InputDevice*) currentlyActiveInputDevice;
-(NSArray* ) currentlyAvailableInputChannels;
-(BOOL) activateFirstInstanceOfInputDeviceWithUniqueName:(NSString *) uniqueName;
-(void) addNewInputDevice:(InputDevice *) newInputDevice;
-(void) removeInputDevice:(InputDevice *) inputDeviceToRemove;
-(void) deactivateInputDevice:(InputDevice *) inputDeviceToDeactivate;
-(BOOL) activateChannelWithConfig:(ChannelConfig *) channelConfigToActivate;
-(BOOL) deactivateChannelWithConfig:(ChannelConfig *) channelConfigToDeactivate;
-(int) getColorIndexForActiveChannelIndex:(int) indexOfChannel;
-(void) updateColorOfActiveChannels;
-(float) getDefaultTimeScale;
-(float) getVoltageScaleForChannelIndex:(int)indexOfChannel;
//select which one is selected on UI
-(void) selectChannel:(int) selectedChannel;
-(void) reactivateCurrentDevice;


//Mfi
-(void) addMfiDeviceWithModelNumber:(NSString *) modelNumber andSerial:(NSString *) serialNum;
-(BOOL) externalAccessoryIsActive;

-(void) removeMfiDeviceWithModelNumber:(NSString *) modelNumber andSerial:(NSString *) serialNum;


- (void) addEvent:(int) eventType withOffset:(int) inOffset;


//FFT
-(float **) getDynamicFFTResult;
-(UInt32) lengthOfFFTData;
-(UInt32) lengthOf30HzData;
-(void) stopFFT;
-(void) startDynanimcFFTForLiveView;
-(void) startDynanimcFFTForRecording:(BBFile *) newFile;
-(UInt32) indexOfFFTGraphBuffer;
-(UInt32) lenghtOfFFTGraphBuffer;
-(float) baseFFTFrequency;
-(void) recalculateFFT;



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

-(void) setFilterLPCutoff:(int) newLPCuttof hpCutoff:(int)newHPCutoff;

@end
