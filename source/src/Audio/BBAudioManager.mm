//
//  BBAudioManager.m
//  New Focus
//
//  Created by Alex Wiltschko on 7/4/12.
//

#import "BBAudioManager.h"
#import "BBAnalysisManager.h"
#import "BBFile.h"
#import "BBSpike.h"
#import "BBSpikeTrain.h"
#import "BBChannel.h"
#import <Accelerate/Accelerate.h>
#import "BBECGAnalysis.h"


//#define RING_BUFFER_SIZE 524288

static BBAudioManager *bbAudioManager = nil;

@interface BBAudioManager ()
{
    Novocaine *audioManager;
    RingBuffer *ringBuffer;
    __block BBAudioFileWriter *fileWriter;
    __block BBAudioFileReader *fileReader;
    DSPThreshold *dspThresholder;
    DSPAnalysis *dspAnalizer;
    dispatch_queue_t seekingQueue;
    float _threshold;
    float _selectionStartTime;
    float _selectionEndTime;
    float _timeSpan;
    float selectionRMS;
    NSMutableArray* _spikeCountInSelection;
    BBFile * _file;
    //precise time used to sinc spikes display with waveform
    float _preciseTimeOfLastData;
    // We need a special flag for seeking around in a file
    // The audio file reader is very sensitive to threading issues,
    // so we have to babysit it quite closely.
    float desiredSeekTimeInAudioFile;
    float lastSeekPosition;
    float * tempCalculationBuffer;//used to load data for display while scrubbing

    UInt32 lastNumberOfSampleDisplayed;//used to find position of selection in trigger view
    
    int _sourceNumberOfChannels;
    float _sourceSamplingRate;
    
    int _selectedChannel;
    
    int maxNumberOfSamplesToDisplay;
    Float32 * tempResamplingIndexes;
    float * tempResamplingBuffer;
    float * tempResampledBuffer;
    bool differentFreqInOut;
    
    //basic stats
    float _currentSTD;
    float _currentMax;
    float _currentMin;
    float _currentMean;
    
    
    //ECG
    BBECGAnalysis * ecgAnalysis;
    
    //======bt thing
   /* EAAccessory *_accessory;
    EASession *_session;
    NSInteger availableBtData;
    NSMutableData *_writeData;
    NSMutableData *_readData;
    */
}

@property BOOL playing;

- (void)loadSettingsFromUserDefaults;

@end

@implementation BBAudioManager

@synthesize samplingRate;
//@synthesize sourceSamplingRate;
//@synthesize sourceNumberOfChannels;

@synthesize numPulsesInDigitalStimulation;
@synthesize stimulationDigitalMessageFrequency;
@synthesize stimulationDigitalDuration;
@synthesize stimulationDigitalDutyCycle;
@synthesize stimulationDigitalFrequency;
@synthesize stimulationPulseFrequency;
@synthesize stimulationPulseDuration;
@synthesize stimulationToneFrequency;
@synthesize stimulationToneDuration;
@synthesize pulseDutyCycle;
@synthesize numPulsesInBiphasicStimulation;
@synthesize numTriggersInThresholdHistory;
@synthesize maxStimulationAmplitude;
@synthesize minStimulationAmplitude;
@synthesize stimulationType;
@synthesize threshold;
@synthesize thresholdDirection;
@synthesize recording;
@synthesize stimulating;
@synthesize thresholding;
@synthesize selecting;
@synthesize playing;
@synthesize seeking;
@synthesize btOn;
@synthesize FFTOn;
@synthesize ECGOn;
@synthesize rtSpikeSorting;


#pragma mark - Singleton Methods
+ (BBAudioManager *) bbAudioManager
{
	@synchronized(self)
	{
		if (bbAudioManager == nil) {
			bbAudioManager = [[BBAudioManager alloc] init];
		}
	}
    return bbAudioManager;
}

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (bbAudioManager == nil) {
            bbAudioManager = [super allocWithZone:zone];
            return bbAudioManager;  // assignment and return on first allocation
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

#pragma mark - Initialization

- (id)init
{
    if (self = [super init])
    {
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(filterParametersChanged) name:FILTER_PARAMETERS_CHANGED object:nil];
        
        audioManager = [Novocaine audioManager];
        
        _sourceSamplingRate =  audioManager.samplingRate;
        _sourceNumberOfChannels = audioManager.numInputChannels;
        
        _selectedChannel = 0;
        _spikeCountInSelection = [[NSMutableArray alloc] initWithCapacity:0];
        
        NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
        [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        tempResamplingIndexes = (Float32 *)calloc(1024, sizeof(Float32));
        tempResamplingBuffer = (float *)calloc(1024, sizeof(float));
        tempResampledBuffer = (float *)calloc(1024, sizeof(float));
        
        maxNumberOfSamplesToDisplay = [[defaults valueForKey:@"numSamplesMaxNew"] integerValue];

        //Setup initial values for statistics
        _currentMax = [[defaults valueForKey:@"numVoltsMax"] floatValue]*0.8;
        _currentMin = -[[defaults valueForKey:@"numVoltsMax"] floatValue]*0.8;
        _currentMean = 0.0f;
        _currentSTD = _currentMax/6.0f;

        ringBuffer = new RingBuffer(maxNumberOfSamplesToDisplay, _sourceNumberOfChannels);
        tempCalculationBuffer = (float *)calloc(maxNumberOfSamplesToDisplay*_sourceNumberOfChannels, sizeof(float));

        lastSeekPosition = -1;
        dspAnalizer = new DSPAnalysis();
        
        
        
        // Set a default input block acquiring data to a big ring buffer.
        [audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
            ringBuffer->AddNewInterleavedFloatData(data, numFrames, numChannels);
        }];
        
        // Initialize parameters to defaults
        [self loadSettingsFromUserDefaults];
        
        recording = false;
        stimulating = false;
        thresholding = false;
        selecting = false;
        FFTOn = false;
        ECGOn = false;
        btOn = false;
        rtSpikeSorting = false;
        
        [self filterParametersChanged];
        
        [audioManager play];
    }
    
    return self;
}


-(void) filterParametersChanged
{
    NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    float lowFilterValue = [[defaults valueForKey:@"lowFilterFreq"] floatValue];
    //Check if cut-off freq is too high
    if(lowFilterValue>(_sourceSamplingRate*0.3f))
    {
        lowFilterValue = (_sourceSamplingRate*0.3f);
        //if cut-off freq is too high change it and save it
        NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
        [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        [defaults setValue:[NSNumber numberWithFloat:lowFilterValue] forKey:@"lowFilterFreq"];
    }
    
    float highFilterValue = [[defaults valueForKey:@"highFilterFreq"] floatValue];
    
    
    //Check if cut-off freq is too high
    if(highFilterValue>(_sourceSamplingRate*0.3f))
    {
        highFilterValue = (_sourceSamplingRate*0.3f);
        //if cut-off freq is too high change it and save it
        NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
        [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        [defaults setValue:[NSNumber numberWithFloat:highFilterValue] forKey:@"highFilterFreq"];
    }
    
    notchIsOn = [[defaults valueForKey:@"notchFilterOn"] boolValue];
    
    NSLog(@" ************     MAKE FILTERS   ******************");
    NSLog(@"Filter: %f - %f", lowFilterValue, highFilterValue);
    if(notchIsOn)
    {
        NSLog(@"Notch active");
    }
    else
    {
        NSLog(@"Notch OFF");
    }
    
    LPFilter= [[NVLowpassFilter alloc] initWithSamplingRate:_sourceSamplingRate];
    LPFilter.cornerFrequency = highFilterValue;
    LPFilter.Q = 0.8f;
    
    //[LPFilter logCoefficients];
    
    if(lowFilterValue<1.0)
    {
        HPFilter = nil;
    }
    else
    {
        //patch for instability interval
        int tempFilterValue = (int)lowFilterValue;
        lowFilterValue = (float) tempFilterValue;
        if(tempFilterValue==2)
        {
            lowFilterValue = 2.2f;
        }
        if(tempFilterValue == 6)
        {
            lowFilterValue = 6.2;
        }
        if(tempFilterValue == 9)
        {
            lowFilterValue = 9.2;
        }
        //end of patch

        HPFilter = [[NVHighpassFilter alloc] initWithSamplingRate:_sourceSamplingRate];
        HPFilter.cornerFrequency = lowFilterValue;
        HPFilter.Q = 0.51f;
    }
    //[HPFilter logCoefficients];
    
    NotchFilter = [[NVNotchFilter alloc] initWithSamplingRate:_sourceSamplingRate];
    NotchFilter.centerFrequency = 60.0f;
    NotchFilter.q = 1.0  ;
    //[NotchFilter logCoefficients];
}



- (void)loadSettingsFromUserDefaults
{
    // Make sure we've got our defaults right, y'know? Important.
    NSDictionary *defaultsDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SettingsDefaults" ofType:@"plist"]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];

    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    self.numPulsesInDigitalStimulation = [[defaults valueForKey:@"numPulsesInDigitalStimulation"] intValue];
    self.stimulationDigitalMessageFrequency = [[defaults valueForKey:@"stimulationDigitalMessageFrequency"] floatValue];
    self.stimulationDigitalDuration = [[defaults valueForKey:@"stimulationDigitalDuration"] floatValue];
    self.stimulationDigitalDutyCycle = [[defaults valueForKey:@"stimulationDigitalDutyCycle"] floatValue];
    self.stimulationDigitalFrequency = [[defaults valueForKey:@"stimulationDigitalFrequency"] floatValue];
    self.stimulationPulseFrequency = [[defaults valueForKey:@"stimulationPulseFrequency"] floatValue];
    self.stimulationPulseDuration = [[defaults valueForKey:@"stimulationPulseDuration"] floatValue];
    self.stimulationToneFrequency = [[defaults valueForKey:@"stimulationToneFrequency"] floatValue];
    self.stimulationToneDuration = [[defaults valueForKey:@"stimulationToneDuration"] floatValue];
    self.pulseDutyCycle = [[defaults valueForKey:@"pulseDutyCycle"] floatValue];
    self.numPulsesInBiphasicStimulation = [[defaults valueForKey:@"numPulsesInBiphasicStimulation"] intValue];
    self.maxStimulationAmplitude = [[defaults valueForKey:@"maxStimulationAmplitude"] floatValue];
    self.minStimulationAmplitude = [[defaults valueForKey:@"minStimulationAmplitude"] floatValue];
    _threshold = [[defaults valueForKey:@"threshold"] floatValue];
    self.stimulationType = (BBStimulationType)[[defaults valueForKey:@"stimulationType"] intValue];

}

#pragma mark - Breakdown
- (void)saveSettingsToUserDefaults
{

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setValue:[NSNumber numberWithInt:numPulsesInDigitalStimulation] forKey:@"numPulsesInDigitalStimulation"];
    [defaults setValue:[NSNumber numberWithFloat:stimulationDigitalMessageFrequency] forKey:@"stimulationDigitalMessageFrequency"];
    [defaults setValue:[NSNumber numberWithFloat:stimulationDigitalDuration] forKey:@"stimulationDigitalDuration"];
    [defaults setValue:[NSNumber numberWithFloat:stimulationDigitalDutyCycle] forKey:@"stimulationDigitalDutyCycle"];
    [defaults setValue:[NSNumber numberWithFloat:stimulationDigitalFrequency] forKey:@"stimulationDigitalFrequency"];
    [defaults setValue:[NSNumber numberWithFloat:stimulationPulseDuration] forKey:@"stimulationPulseDuration"];
    [defaults setValue:[NSNumber numberWithFloat:stimulationToneFrequency] forKey:@"stimulationToneFrequency"];
    [defaults setValue:[NSNumber numberWithFloat:stimulationToneDuration] forKey:@"stimulationToneDuration"];
    [defaults setValue:[NSNumber numberWithFloat:pulseDutyCycle] forKey:@"pulseDutyCycle"];
    [defaults setValue:[NSNumber numberWithInt:numPulsesInBiphasicStimulation] forKey:@"numPulsesInBiphasicStimulation"];
    [defaults setValue:[NSNumber numberWithFloat:maxStimulationAmplitude] forKey:@"maxStimulationAmplitude"];
    [defaults setValue:[NSNumber numberWithFloat:minStimulationAmplitude] forKey:@"minStimulationAmplitude"];
    [defaults setValue:[NSNumber numberWithInt:stimulationType] forKey:@"stimulationType"];
    [defaults setValue:[NSNumber numberWithFloat:_threshold] forKey:@"threshold"];
    [defaults synchronize];
}

#pragma mark - Bluetooth

-(void) testBluetoothConnection
{
   // [[BBBTManager btManager] startBluetooth];
}

-(void) switchToBluetoothWithChannels:(int) channelConfiguration andSampleRate:(int) inSampleRate
{
  /*  btOn = YES;
    [[BBBTManager btManager] configBluetoothWithChannelConfiguration:channelConfiguration andSampleRate:inSampleRate];
    _sourceSamplingRate=inSampleRate;
    _sourceNumberOfChannels=[[BBBTManager btManager] numberOfChannels];
    
    [self stopAllInputOutput];
    [self resetBuffers];
    [self makeInputOutput];*/
}

-(void) closeBluetooth
{
    /*[self stopAllInputOutput];
    [[BBBTManager btManager] stopCurrentBluetoothConnection];
    _sourceSamplingRate =  audioManager.samplingRate;
    _sourceNumberOfChannels = audioManager.numInputChannels;
    btOn = NO;
    [self resetBuffers];
    [self makeInputOutput];
    [[NSNotificationCenter defaultCenter] postNotificationName:RESETUP_SCREEN_NOTIFICATION object:self];*/
}

-(int) numberOfFramesBuffered
{
    return 0;//[[BBBTManager btManager] numberOfFramesBuffered];
}


#pragma mark - Helper functions


-(void) stopAllInputOutput
{
    //[[BBBTManager btManager] setInputBlock:nil];
    audioManager.inputBlock = nil;
    audioManager.outputBlock = nil;
}

-(void) getChannelsConfig
{
    if(btOn)
    {
     /*   _sourceSamplingRate =  [[BBBTManager btManager] samplingRate];
        _sourceNumberOfChannels = [[BBBTManager btManager] numberOfChannels];*/
    }
    else
    {
        _sourceSamplingRate =  audioManager.samplingRate;
        _sourceNumberOfChannels = audioManager.numInputChannels;
    }
}



-(void) resetBuffers
{

    delete ringBuffer;
    free(tempCalculationBuffer);
    //create new buffers
    
    ringBuffer = new RingBuffer(maxNumberOfSamplesToDisplay, _sourceNumberOfChannels);
    tempCalculationBuffer = (float *)calloc(maxNumberOfSamplesToDisplay*_sourceNumberOfChannels, sizeof(float));
    [self filterParametersChanged];
    if(rtSpikeSorting)
    {
        [[BBAnalysisManager bbAnalysisManager] stopRTSpikeSorting];
        [[BBAnalysisManager bbAnalysisManager] initRTSpikeSorting:_sourceSamplingRate];
    }
}

-(void) makeInputOutput
{
   // [self resetBuffers];
    
    if(btOn)
    {
        //Get the data
      /*  [[BBBTManager btManager] setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels)
        {
             [self additionalProcessingOfInputData:data forNumOfFrames:numFrames andNumChannels:numChannels];
            
             ringBuffer->AddNewInterleavedFloatData(data, numFrames, numChannels);
        }];
        
        //Trigger data collection on precise timing
        [audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
            [[BBBTManager btManager] needData:((float)numFrames)/((float)audioManager.samplingRate) ];
            memset(data, 0, numChannels*numFrames*sizeof(float));
        }];
        
        */
    }
    else
    {
        // Replace the input block with the old input block, where we just save an in-memory copy of the audio.
        [audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
           
            [self additionalProcessingOfInputData:data forNumOfFrames:numFrames andNumChannels:numChannels];
            
            ringBuffer->AddNewInterleavedFloatData(data, numFrames, numChannels);
           
        }];
    }
}

-(void) additionalProcessingOfInputData:(float *) data forNumOfFrames:(UInt32) numFrames andNumChannels:(UInt32) numChannels
{
    
    if (recording)
    {
        [fileWriter writeNewAudio:data numFrames:numFrames numChannels:numChannels];
    }
    
   // [self filterData:data numFrames:numFrames numChannels:numChannels];
    [self updateBasicStatsOnData:data numFrames:numFrames numChannels:numChannels];
   
    if (thresholding)
    {
        dspThresholder->ProcessNewAudio(data, numFrames);
    }
    
    if(playing)
    {
        // do nothing with input from MIC/BT
    }
    
    if(FFTOn)
    {
        dspAnalizer->CalculateDynamicFFT(data, numFrames, _selectedChannel);
    }
    
    if(ECGOn)
    {
         [ecgAnalysis calculateECGWithThreshold:data numberOfFrames:numFrames selectedChannel:_selectedChannel];
       // [ecgAnalysis calculateECGAnalysis:data numberOfFrames:numFrames selectedChannel:_selectedChannel];
    }
    
    if(rtSpikeSorting)
    {
        [[BBAnalysisManager bbAnalysisManager] findSpikesInRTForData:data numberOfFrames:numFrames numberOfChannel:numChannels selectedChannel:_selectedChannel];
    }
    
}

-(void) filterData:(float *)newData numFrames:(UInt32)thisNumFrames numChannels:(UInt32)thisNumChannels
{
    int i;
    if(thisNumChannels>2)
    {
        for(i=0;i<_sourceNumberOfChannels;i++)
        {
            float zero = 0.0f;
            //get selected channel
            vDSP_vsadd((float *)&newData[i],
                       thisNumChannels,
                       &zero,
                       tempResamplingBuffer,
                       1,
                       thisNumFrames);
            //
            if(HPFilter)
            {
                [HPFilter filterData:tempResamplingBuffer numFrames:thisNumFrames numChannels:1];
            }
            [LPFilter filterData:tempResamplingBuffer numFrames:thisNumFrames numChannels:1];
            if(notchIsOn)
            {
                [NotchFilter filterData:tempResamplingBuffer numFrames:thisNumFrames numChannels:1];
            }
            
            vDSP_vsadd(tempResamplingBuffer,
                       1,
                       &zero,
                       (float *)&newData[i],
                       thisNumChannels,
                       thisNumFrames);
        }
    }
    else
    {
        if(HPFilter)
        {
            [HPFilter filterData:newData numFrames:thisNumFrames numChannels:thisNumChannels];
        }
        [LPFilter filterData:newData numFrames:thisNumFrames numChannels:thisNumChannels];
        if(notchIsOn)
        {
            [NotchFilter filterData:newData numFrames:thisNumFrames numChannels:thisNumChannels];
        }
    }
}


-(void) updateBasicStatsOnData:(float *)newData numFrames:(UInt32)thisNumFrames numChannels:(UInt32)thisNumChannels
{
    //get data for selected channel
    float zero = 0.0f;
    //get selected channel
    vDSP_vsadd((float *)&newData[_selectedChannel],
               thisNumChannels,
               &zero,
               tempResamplingBuffer,
               1,
               thisNumFrames);
    
    dspAnalizer->calculateBasicStats(tempResamplingBuffer, thisNumFrames, &_currentSTD, &_currentMin, &_currentMax, &_currentMean);
    
    self.currSTD = 0.001*_currentSTD + 0.999*self.currSTD;
    self.currMean = 0.001*_currentMean + 0.999*self.currMean;
    
   /* if(self.currMin>_currentMin)
    {
        self.currMin = _currentMin;
    }*/
    self.currMin = ringBuffer->Min();
    /*if(self.currMax<_currentMax)
    {
        self.currMax = _currentMax;
    }*/
    self.currMax = ringBuffer->Max();
    if(ABS(self.currMin)>self.currMax)
    {
        self.currMax = ABS(self.currMin);
    }
}

-(void) quitAllFunctions
{
    
    [self stopAllInputOutput];
    
    if (recording)
    {
        [self stopRecording];
    }
    if (thresholding)
    {
        [self stopThresholding];
    }
    
    if(playing)
    {
        [self stopPlaying];
    }
    
    if(FFTOn)
    {
        [self stopFFT];
    }
    
    if(ECGOn)
    {
        [self stopECG];
    }
    
    if(rtSpikeSorting)
    {
        [self stopRTSpikeSorting];
    }
    
}


#pragma mark - Input Methods
- (void)startMonitoring
{
    [self quitAllFunctions];
    [self getChannelsConfig];
    [self makeInputOutput];
}


#pragma mark - Thresholding

- (void)startThresholding:(UInt32)newNumPointsToSavePerThreshold
{
    [self quitAllFunctions];
    [self getChannelsConfig];
    [self makeInputOutput];
    numPointsToSavePerThreshold = newNumPointsToSavePerThreshold;

    if (dspThresholder) {
        NSLog(@"DSP already made");
        dspThresholder->SetRingBuffer(ringBuffer);
        dspThresholder->SetNumberOfChannels(_sourceNumberOfChannels);
        
    }
    else
    {
        NSLog(@"DSP not made");
        dspThresholder = new DSPThreshold(ringBuffer, numPointsToSavePerThreshold, 50,_sourceNumberOfChannels);
       
    }
    dspThresholder->SetThreshold(_threshold);
    
    NSLog(@"Select threshold channel from BB audio init");
    dspThresholder->SetSelectedChannel(_selectedChannel);
    
    thresholding = true;
}

- (void)stopThresholding
{
    thresholding = false;
}


- (void)setThreshold:(float)newThreshold
{
    _threshold = newThreshold;
    
    if (dspThresholder)
        dspThresholder->SetThreshold(newThreshold);
}

- (float)threshold
{
    
    if (dspThresholder) {
        _threshold = dspThresholder->GetThreshold();
        return _threshold;
    }
    else {
        return 0;
    }
}

- (BBThresholdType)thresholdDirection
{
    if (dspThresholder) {
        return dspThresholder->GetThresholdDirection();
    }
    
    return BBThresholdTypeNone;
    
}

- (void)setThresholdDirection:(BBThresholdType)newThresholdDirection
{
    if (dspThresholder) {
        dspThresholder->SetThresholdDirection(newThresholdDirection);
    }
}

#pragma mark - Recording

- (void)startRecording:(NSURL *)urlToFile
{
    // If we're already recording, skip out
    if (recording == true) {
        return;
    }
    else {
        
        
        
        // Grab a file writer. This takes care of the creation and management of the audio file.
        fileWriter = [[BBAudioFileWriter alloc]
                      initWithAudioFileURL:urlToFile 
                      samplingRate:_sourceSamplingRate
                      numChannels:_sourceNumberOfChannels];
        
        // Replace the audio input function
        [self makeInputOutput];
        recording = true;
        
    }
}

- (void)stopRecording
{
    recording = false;
    
    [fileWriter stop];
    // do the breakdown
    [fileWriter release];
    fileWriter = nil;

}


#pragma mark - RT Spike Sorting

-(float *) rtSpikeValues
{
    return [[BBAnalysisManager bbAnalysisManager] rtPeaksValues];
}
-(float *) rtSpikeIndexes
{
    return [[BBAnalysisManager bbAnalysisManager] rtPeaksIndexs];
}

-(int) numberOfRTSpikes
{
    return [[BBAnalysisManager bbAnalysisManager] numberOfRTSpikes];
}

-(void) stopRTSpikeSorting
{
    if(rtSpikeSorting)
    {
        rtSpikeSorting = false;
        [[BBAnalysisManager bbAnalysisManager] stopRTSpikeSorting];
    }

}

-(void) startRTSpikeSorting
{
    [[BBAnalysisManager bbAnalysisManager] initRTSpikeSorting:_sourceSamplingRate];
    rtSpikeSorting = true;
}

-(void) setRtThresholdFirst:(float)rtThreshold
{
    [[BBAnalysisManager bbAnalysisManager] setRtThresholdFirst:rtThreshold];
}

-(void) setRtThresholdSecond:(float)rtThreshold
{
    [[BBAnalysisManager bbAnalysisManager] setRtThresholdSecond:rtThreshold];
}

-(float) rtThresholdFirst
{
    return [[BBAnalysisManager bbAnalysisManager] rtThresholdFirst];
}

-(float) rtThresholdSecond
{
    return [[BBAnalysisManager bbAnalysisManager] rtThresholdSecond];
}


#pragma mark - ECG code

-(void) startECG
{
    [self quitAllFunctions];
    [self getChannelsConfig];
    [self makeInputOutput];
    
    if(ecgAnalysis)
    {
        [ecgAnalysis release];
    }
    ecgAnalysis = [[BBECGAnalysis alloc] init];
    [ecgAnalysis initECGAnalysisWithSamplingRate:_sourceSamplingRate numOfChannels:_sourceNumberOfChannels];
    ECGOn = true;
}

-(void) stopECG
{

    ECGOn = false;
}


-(float) heartRate
{
    return [ecgAnalysis heartRate];
}

-(BOOL) heartBeatPresent
{
    return [ecgAnalysis heartBeatPresent];
}

-(float) ecgThreshold
{
    return [ecgAnalysis extThreshold];
}

-(void) setEcgThreshold:(float) inEcgThreshold
{
    [ecgAnalysis setExtThreshold:inEcgThreshold];
}

#pragma mark - Playback

- (void)startPlaying:(BBFile *) fileToPlay
{
    [self stopAllInputOutput];
    
    if (self.playing == true)
        return;
    
    
    if (self.playing == false && fileReader != nil)
    {
        [fileReader release];
        fileReader = nil;
    }
    
    _file = fileToPlay;
    
    
    //Check sampling rate and number of channels in file
    NSError *avPlayerError = nil;
    AVAudioPlayer *avPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[_file fileURL] error:&avPlayerError];
    if (avPlayerError)
    {
        NSLog(@"Error opening file: %@", [avPlayerError description]);
        _sourceNumberOfChannels =1;
        _sourceSamplingRate = 44100.0f;
    }
    else
    {
        _sourceNumberOfChannels = [avPlayer numberOfChannels];
        _sourceSamplingRate = [[[avPlayer settings] objectForKey:AVSampleRateKey] floatValue];
        NSLog(@"Source file num. of channels %d, sampling rate %f", _sourceNumberOfChannels, _sourceSamplingRate);
    }
    [avPlayer release];
    avPlayer = nil;
    

    //Free memory
    [self resetBuffers];
    
    free(tempResamplingBuffer);
    free(tempResampledBuffer);
    tempResamplingBuffer = (float *)calloc(1024, sizeof(float));
    tempResampledBuffer = (float *)calloc(1024, sizeof(float));

    fileReader = [[BBAudioFileReader alloc]
                  initWithAudioFileURL:[_file fileURL]
                  samplingRate:_sourceSamplingRate
                  numChannels:_sourceNumberOfChannels];
    
    differentFreqInOut = _sourceSamplingRate != audioManager.samplingRate;
    
    
    [audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
        
        
        //------- Scrubbing ----------------
        UInt32 realNumberOfFrames = (UInt32)(((float)numFrames)*(_sourceSamplingRate/audioManager.samplingRate));

       
        Float32 zero = 0;
        Float32 increment = (float)(realNumberOfFrames)/(float)(numFrames);
        vDSP_vramp(&zero, &increment, tempResamplingIndexes, 1, numFrames);//here may be numFrames-1
        
        
        if (!self.playing) {
            //if we have new seek position
            if(self.seeking && lastSeekPosition != fileReader.currentTime)
            {
                lastSeekPosition = fileReader.currentTime;
                //clear ring buffer

                
                //calculate begining and end of interval to display
                UInt32 targetFrame = (UInt32)(fileReader.currentTime * ((float)_sourceSamplingRate));
                int startFrame = targetFrame - maxNumberOfSamplesToDisplay;
                if(startFrame<0)
                {
                    startFrame = 0;
                }

                //get the data from file into clean ring buffer
                dispatch_sync(dispatch_get_main_queue(), ^{
                    ringBuffer->Clear();
                    ringBuffer->SeekWriteHeadPosition(0);
                    ringBuffer->SeekReadHeadPosition(0);
                    [fileReader retrieveFreshAudio:tempCalculationBuffer numFrames:(UInt32)(targetFrame-startFrame) numChannels:_sourceNumberOfChannels seek:(UInt32)startFrame];
                    
                    
                    //Filtering of recorded data while scrolling
                    //[self filterData:tempCalculationBuffer numFrames:(UInt32)(targetFrame-startFrame) numChannels:_sourceNumberOfChannels];
                    
                    
                    
                    
                    ringBuffer->AddNewInterleavedFloatData(tempCalculationBuffer, targetFrame-startFrame, _sourceNumberOfChannels);
                  
                    _preciseTimeOfLastData = (float)targetFrame/(float)_sourceSamplingRate;

                    //set playback time to scrubber position
                    fileReader.currentTime = lastSeekPosition;
                    if(selecting)
                    {
                         //if we have active selection recalculate RMS
                        [self updateSelection:_selectionEndTime timeSpan:_timeSpan];
                    }
                });
            }
            
            //set playback data to zero (silence during scrubbing)
            memset(data, 0, numChannels*numFrames*sizeof(float));
            return;
        }
        
        
        
        //------- Playing ----------------
        
        
        //we keep currentTime here to have precise time to sinc spikes marks display with waveform
        dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH , 0), ^{
         //dispatch_sync(dispatch_get_main_queue(), ^{
            
            //get all data (wil get more than 2 cannels in buffer)
            [fileReader retrieveFreshAudio:tempCalculationBuffer numFrames:realNumberOfFrames numChannels:_sourceNumberOfChannels];
            
            
            
            //FIltering of playback data
          //  [self filterData:tempCalculationBuffer numFrames:realNumberOfFrames numChannels:_sourceNumberOfChannels];
            
            
            //move just numChannels in buffer
            float zero = 0.0f;
           
            if(differentFreqInOut)
            {
                //make interpolation
                vDSP_vsadd((float *)&tempCalculationBuffer[_selectedChannel],
                           _sourceNumberOfChannels,
                           &zero,
                           &tempResamplingBuffer[1],
                           1,
                           realNumberOfFrames);
                vDSP_vlint(tempResamplingBuffer, tempResamplingIndexes, 1, tempResampledBuffer, 1, numFrames, realNumberOfFrames);
                
                for (int iChannel = 0; iChannel < numChannels; ++iChannel) {

                    vDSP_vsadd(tempResampledBuffer,
                               1,
                               &zero,
                               &data[iChannel],
                               numChannels,
                               numFrames);
                }
                tempResamplingBuffer[0] = tempResamplingBuffer[realNumberOfFrames];
            }
            else
            {
                for (int iChannel = 0; iChannel < numChannels; ++iChannel) {
                        vDSP_vsadd((float *)&tempCalculationBuffer[_selectedChannel],
                                   _sourceNumberOfChannels,
                                   &zero,
                                   &data[iChannel],
                                   numChannels,
                                   numFrames);
                }
            }
          
            ringBuffer->AddNewInterleavedFloatData(tempCalculationBuffer, realNumberOfFrames, _sourceNumberOfChannels);
            _preciseTimeOfLastData = fileReader.currentTime;
            [self updateBasicStatsOnData:tempCalculationBuffer numFrames:realNumberOfFrames numChannels:_sourceNumberOfChannels];
            

            
        });
        
        
        
        //------- Stop - End of file ----------------
        
        if (fileReader.fileIsDone) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                fileReader.currentTime = 0.0f;
                _preciseTimeOfLastData = 0.0f;
                ringBuffer->Clear();
                [self pausePlaying];
            });
            return;
        }
        
    }];
    
    [self resumePlaying];
    
    
}

-(void) clearWaveform
{
    if(ringBuffer)
    {
        ringBuffer->Clear();
    }
}

- (void)stopPlaying
{
    if(self.playing)
    {
        [self pausePlaying];
        _file = nil;
        _preciseTimeOfLastData = 0.0f;
        // Toss the file reader.
        [fileReader release];
        fileReader = nil;
        ringBuffer->Clear();
    }
}

- (void)pausePlaying
{
    self.playing = false;
}

- (void)resumePlaying
{
    self.playing = true;
}


#pragma mark - FFT code


-(float **) getDynamicFFTResult
{
    return dspAnalizer->FFTDynamicMagnitude;
}


-(void) startDynanimcFFT
{
    float maxNumOfSeconds = MAX_NUMBER_OF_FFT_SEC;
    [self quitAllFunctions];
    [self getChannelsConfig];
    //Try to make under 1Hz resolution
    //if it is too much than limit it to samplingRate/2^11
    uint32_t log2n = log2f((float)_sourceSamplingRate);
    
    uint32_t n = 1 << (log2n+2);
    
    [self makeInputOutput];// here we also create ring buffer so it must be before we set ring buffer
    
    dspAnalizer->InitDynamicFFT(ringBuffer, _sourceNumberOfChannels, _sourceSamplingRate, n, 95, maxNumOfSeconds);
    
    FFTOn = true;
    
}


-(void) stopFFT
{
    if (!FFTOn)
        return;
    
    FFTOn = false;
    [self makeInputOutput];
}

-(UInt32) lengthOfFFTData
{
    return dspAnalizer->LengthOfFFTData;
}

-(UInt32) lengthOf30HzData
{
    return dspAnalizer->LengthOf30HzData;
}

-(UInt32) lenghtOfFFTGraphBuffer
{
    return dspAnalizer->NumberOfGraphsInBuffer;
}

-(UInt32) indexOfFFTGraphBuffer
{
    return dspAnalizer->GraphBufferIndex;
}

//-(float *) movingAverageFFT
//{
//    return dspAnalizer->movingAverageFFT;
//}


#pragma mark - data feed for graphs

- (float)fetchAudio:(float *)data numFrames:(UInt32)numFrames whichChannel:(UInt32)whichChannel stride:(UInt32)stride
{
    if(whichChannel>=_sourceNumberOfChannels)
    {
        return 0.0f;
    }
    if (!thresholding) {
        //Fetch data and get time of data as precise as posible. Used to sichronize
        //display of waveform and spike marks
        float timeOfData = ringBuffer->FetchFreshData2(data, numFrames, whichChannel, stride);
        return timeOfData;
    }
    else if (thresholding) {

        lastNumberOfSampleDisplayed = numFrames;
        dspThresholder->GetCenteredTriggeredData(data, numFrames, whichChannel, stride);
        //if we have active selection recalculate RMS
        if(selecting)
        {
            [self updateSelection:_selectionEndTime timeSpan:_timeSpan];
            
        }
    }
    return 0.0f;
}

- (float)fetchAudioForSelectedChannel:(float *)data numFrames:(UInt32)numFrames stride:(UInt32)stride
{
    return [self fetchAudio:data numFrames:numFrames whichChannel:_selectedChannel stride:stride];
    
}

-(NSMutableArray *) getChannels
{
    return [_file allChannels];
}



#pragma mark - Output Methods
- (void)startStimulating:(BBStimulationType)newStimulationType
{
        
    self.stimulating = true;
    self.stimulationType = newStimulationType;

    // PWM
    // ============================================================
    if (stimulationType == BBStimulationTypePWM) {
        __block int sample = 0;
        
        [audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
            int numSamplesInPeriod = audioManager.samplingRate / stimulationPulseFrequency;
            int numSamplesOn = (int)(pulseDutyCycle * audioManager.samplingRate / stimulationPulseFrequency);
            for (int i=0; i < numFrames; ++i) {
                for (int iChannel = 0; iChannel < numChannels; ++iChannel) {
                    data[i*numChannels+iChannel] = (sample < numSamplesOn) ? maxStimulationAmplitude : minStimulationAmplitude;
                }
                sample += 1;
                if (sample >= numSamplesInPeriod) {
                    sample = 0;
                }
            }
        }];
        
    }
    
    
    
    else if (stimulationType == BBStimulationTypePWMPulse) {
        
        __block float secondsPlayed = 0.0f;
        __block int sample = 0;
        
        [audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
            
            if (secondsPlayed < stimulationPulseDuration) {
                
                int numSamplesInPeriod = audioManager.samplingRate / stimulationPulseFrequency;
                int numSamplesOn = (int)(pulseDutyCycle * audioManager.samplingRate / stimulationPulseFrequency);
                for (int i=0; i < numFrames; ++i) {
                    for (int iChannel = 0; iChannel < numChannels; ++iChannel) {
                        data[i*numChannels+iChannel] = (sample < numSamplesOn) ? maxStimulationAmplitude : minStimulationAmplitude;
                    }
                    sample += 1;
                    if (sample >= numSamplesInPeriod) {
                        sample = 0;
                    }
                    
                    
                }
                secondsPlayed += (float)numFrames / self.samplingRate;
            }
            else {
                audioManager.outputBlock = nil;
                self.stimulating = false;
            }
        }];
    }

    
    
    // Single-shot PWM
    // ============================================================
    
    // The pulses should be 1ms width. 
    else if (stimulationType == BBStimulationTypeBiphasic) {

        __block int sample = 0;
        __block int numPulsesPlayed = 0;
        
        [audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
            
            int numSamplesInPeriod = audioManager.samplingRate / self.stimulationPulseFrequency;
            int numSamplesOn = (int)(audioManager.samplingRate / 1000.0f); // always 1ms pulses
            
            if (numPulsesPlayed < numPulsesInBiphasicStimulation) {
                
                for (int i=0; i < numFrames; ++i) {
                    for (int iChannel = 0; iChannel < numChannels; ++iChannel) {
                        data[i*numChannels+iChannel] = (sample < numSamplesOn) ? maxStimulationAmplitude : minStimulationAmplitude;
                    }
                    sample = sample + 1;
                    if (sample >= numSamplesInPeriod) {
                        sample = 0;
                        numPulsesPlayed = numPulsesPlayed + 1;
                    }
                }
                
            }
            
            else {
                audioManager.outputBlock = nil;
                self.stimulating = false;
            }
            
        }];
    }
    
    // Pure Tone
    // ============================================================
    else if (stimulationType == BBStimulationTypeTone) {
        
        __block float phase = 0.0;
        
        [audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels)
         {

             for (int i=0; i < numFrames; ++i)
             {
                 for (int iChannel = 0; iChannel < numChannels; ++iChannel) 
                 {
                     float theta = phase * M_PI * 2;
                     data[i*numChannels + iChannel] = sin(theta);
                 }
                 phase += 1.0 / (self.samplingRate / self.stimulationToneFrequency);
                 if (phase > 1.0) phase = -1;
             }
         }];
    }
    
    // Pure Tone Pulse
    // ============================================================

    else if (stimulationType == BBStimulationTypeTonePulse) {
        
        __block float phase = 0.0f;
        __block float secondsPlayed = 0.0f;
        
        [audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
            
            if (secondsPlayed < stimulationToneDuration) {
            
                for (int i=0; i < numFrames; ++i)
                {
                    for (int iChannel = 0; iChannel < numChannels; ++iChannel) 
                    {
                        float theta = phase * M_PI * 2;
                        data[i*numChannels + iChannel] = sin(theta);
                    }
                    phase += 1.0 / (self.samplingRate / self.stimulationToneFrequency);
                    if (phase > 1.0) phase = -1;
                }
                secondsPlayed += (float)numFrames / self.samplingRate;
            }

            else {
                audioManager.outputBlock = nil;
                self.stimulating = false;
            }

        }];
    }
    
    
    // Digital Control (bursts of high-frequency pure tones, ~20KHz,
    // which custom hardware is designed to interpret)
    // ============================================================
    

        
    else if (stimulationType == BBStimulationTypeDigitalControlPulse) {
        __block float pulsed_phase = 0.0f;
        __block int pulsed_sample = 0;
        __block int numPulsesPlayed = 0;

        
       [audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
            
            int numSamplesInPeriod = audioManager.samplingRate / self.stimulationDigitalFrequency;
            int numSamplesOn = (int)(self.stimulationDigitalDutyCycle * audioManager.samplingRate / self.stimulationDigitalFrequency);
            
            if (numPulsesPlayed < self.numPulsesInDigitalStimulation) {

                if (pulsed_sample + numFrames >= numSamplesInPeriod) {
                    numPulsesPlayed += 1;
                    
                    if (numPulsesPlayed == self.numPulsesInDigitalStimulation) {
                        numFrames = numSamplesInPeriod - pulsed_sample;
                    }
                }
                
                float lsamplingRate = self.samplingRate;
                float messageFrequency = self.stimulationDigitalMessageFrequency;
            
                for (int i=0; i < numFrames; ++i) {
                    for (int iChannel = 0; iChannel < numChannels; ++iChannel) {
                        float theta = pulsed_phase * M_PI * 2;
                        data[i*numChannels+iChannel] = (pulsed_sample < numSamplesOn) ? sin(theta) : 0.0f;
                    }

                    pulsed_phase += 1.0 / (lsamplingRate / messageFrequency);
                    if (pulsed_phase > 1.0) pulsed_phase -= 2; // TODO: test this thingy
                    pulsed_sample += 1;
                    if (pulsed_sample >= numSamplesInPeriod) {
                        pulsed_sample = 0;
                    }
                    
                }

            }

            else {
                audioManager.outputBlock = nil;
                self.stimulating = false;
            }
        }];
    }
    
    
    else if (stimulationType == BBStimulationTypeDigitalControl) {
        
        __block float phase = 0.0f;
        __block int sample = 0;
        
        [audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
            
            int numSamplesInPeriod = audioManager.samplingRate / self.stimulationDigitalFrequency;
            int numSamplesOn = (int)(self.stimulationDigitalDutyCycle * audioManager.samplingRate / self.stimulationDigitalFrequency);
            
            float lsamplingRate = self.samplingRate;
            float messageFrequency = self.stimulationDigitalMessageFrequency;
            
            for (int i=0; i < numFrames; ++i) {
                for (int iChannel = 0; iChannel < numChannels; ++iChannel) {
                    float theta = phase * M_PI * 2;
                    data[i*numChannels+iChannel] = (sample < numSamplesOn) ? sin(theta) : 0.0f;
                }
                
                phase += 1.0 / (lsamplingRate / messageFrequency);
                if (phase > 1.0) phase -= 2; // TODO: test this thingy
                sample += 1;
                if (sample >= numSamplesInPeriod) {
                    sample = 0;
                }
            }

                        
        }];
    }
    
    
    
    
}


- (void)stopStimulating
{
    self.stimulating = false;
    audioManager.outputBlock = nil;    
}

#pragma mark - Spikes

-(NSMutableArray *) getSpikes
{
    
    //TODO: Check if this is ok:
    if(_file && [_file.allSpikes count]>0)
    {
        return _file.allSpikes;
    }
    
    return nil;
}

-(float) getTimeForSpikes
{
   
    return _preciseTimeOfLastData;
    
}


#pragma mark - Selection analysis

-(void) calculateSpikeCountInSelection
{
    [_spikeCountInSelection removeAllObjects];
    
    BBSpike * tempSpike;
    BBSpike * lastSpike;
    float averageISI;
    BBChannel * tempChannel;
    BBSpikeTrain * tempSpikeTrain;
    float startTime, endTime;
    //selection times are negative so we need oposite logic
    if(_selectionEndTime> _selectionStartTime)
    {
        startTime = _selectionEndTime ;
        endTime = _selectionStartTime ;

    }
    else
    {
        startTime = _selectionStartTime ;
        endTime = _selectionEndTime ;
    }
   // startTime = _timeSpan-startTime;
   // endTime = _timeSpan - endTime;
    startTime = [self currentFileTime]-startTime;
    endTime = [self currentFileTime] - endTime;
    
    BOOL weAreInInterval;

    tempChannel = [[_file allChannels] objectAtIndex:_selectedChannel];

    for(int trainIndex=0;trainIndex<[[tempChannel spikeTrains] count];trainIndex++)
    {
        tempSpikeTrain = [[tempChannel spikeTrains] objectAtIndex:trainIndex];
        
        
        weAreInInterval = NO;

  
        int i = 0;
        averageISI = 0.0f;
        //go through all spikes
        for (tempSpike in tempSpikeTrain.spikes) {
           
            if([tempSpike time]>startTime && [tempSpike time]<endTime)
            {
                i++;

                if(i>1)
                {
                    averageISI += tempSpike.time - lastSpike.time;
                }
                lastSpike = tempSpike;
                
            }
            else if(weAreInInterval)
            {//if we pass last spike in selected interval
                break;
            }
        }
        
        [_spikeCountInSelection addObject:[NSNumber numberWithInt:i]];
        if(i>1)
        {
            i--;
            averageISI = averageISI/(float)i;
            averageISI = 1.0f/averageISI;
            [_spikeCountInSelection addObject:[NSNumber numberWithFloat:averageISI]];
        }
        else
        {
            [_spikeCountInSelection addObject:[NSNumber numberWithFloat:0.0f]];
        }
    }
}


-(float) calculateSelectionRMS
{
    
    int startSample, endSample;
    //selection times are negative so we need oposite logic
    if(_selectionEndTime> _selectionStartTime)
    {
        startSample = _selectionStartTime * [self sourceSamplingRate];
        endSample = _selectionEndTime * [self sourceSamplingRate];
    }
    else
    {
        startSample = _selectionEndTime * [self sourceSamplingRate];
        endSample = _selectionStartTime * [self sourceSamplingRate];
    }
    
    
    // Aight, now that we've got our ranges correct, let's ask for the audio.
    memset(tempCalculationBuffer, 0, _sourceNumberOfChannels*maxNumberOfSamplesToDisplay*sizeof(float));
    
    if (!thresholding) {
        //fetchAudio will put all data (from left time limit to right edge of the screen) at the begining
        //of the display buffer. After that we just take data from begining of the buffer to the length of
        //selected time interval and calculate RMS
        ringBuffer->FetchFreshData2(tempCalculationBuffer, endSample, _selectedChannel , 1);
        selectionRMS =dspAnalizer->RMSSelection((tempCalculationBuffer), endSample-startSample);
    }
    else if (thresholding) {
        //we first get all the data that is displayed on the screen and then we chose only segment that is selected
        //this is done lake this because GetCenteredTriggeredData is returning always centered data
        dspThresholder->GetCenteredTriggeredData(tempCalculationBuffer, lastNumberOfSampleDisplayed,_selectedChannel, 1);
        selectionRMS =dspAnalizer->RMSSelection((tempCalculationBuffer+lastNumberOfSampleDisplayed-endSample), endSample-startSample);

    }
    return selectionRMS;
}





- (float)rmsOfSelection
{
    return selectionRMS;
}


#pragma mark - State

//
// Selected channel to play and analyse
//
-(void) selectChannel:(int) selectedChannel
{
    NSLog(@"IN Audio selected channel: %d", selectedChannel);
    _selectedChannel = selectedChannel;
    if(thresholding)
    {
        dspThresholder->SetSelectedChannel(_selectedChannel);
    }
    if(rtSpikeSorting)
    {
        [[BBAnalysisManager bbAnalysisManager] clearRTSpikes];
    }
}

//private. Starts selection functionality
-(void) startSelection:(float) newSelectionStartTime
{
    _selectionStartTime = newSelectionStartTime;
    _selectionEndTime = newSelectionStartTime;
    selecting = true;
}

//Ends selection functionality
-(void) endSelection
{
    selecting = false;
    selectionRMS = 0;
}

//Update selection interval
//
// newSelectionTime is time from right end of the screen to touch (positive value)
//
-(void) updateSelection:(float) newSelectionTime timeSpan:(float)timeSpan
{
    _timeSpan = timeSpan;
    if(selecting)
    {
        _selectionEndTime = newSelectionTime;
        selectionRMS = [self calculateSelectionRMS];
        [self calculateSpikeCountInSelection];
    }
    else
    {
        [self startSelection:newSelectionTime];
        selectionRMS = 0;
    }
    
}

- (float) selectionStartTime
{
    return _selectionStartTime;
}

- (float) selectionEndTime
{
    return _selectionEndTime;
}

-(NSMutableArray *) spikesCount
{
    return _spikeCountInSelection;
}


- (float)currentFileTime
{
    if (fileReader) {
        return fileReader.currentTime;
    }
    if (fileWriter) {
        return fileWriter.duration;
    }

    return 0;
}

- (void)setCurrentFileTime:(float)newCurrentFileTime
{
    
    if (fileReader) {
        if(fileReader.duration<newCurrentFileTime)
        {
            newCurrentFileTime = fileReader.duration;
        }
        fileReader.currentTime = newCurrentFileTime;
    }
}

- (float)fileDuration
{
    
    if (fileReader) {
        return fileReader.duration;
    }
    if (fileWriter) {
        return fileWriter.duration;
    }
    
    return 0;
    
}

- (float)samplingRate
{
    return audioManager.samplingRate;
}

-(int) numberOfChannels
{
    return audioManager.numInputChannels;
}


- (float) sourceSamplingRate
{
    return _sourceSamplingRate;
}

-(int) sourceNumberOfChannels
{
    return _sourceNumberOfChannels;
}

- (void)setNumTriggersInThresholdHistory:(UInt32)numTriggersInThresholdHistoryLocal
{
    if (dspThresholder)
    {
        dspThresholder->SetNumTriggersInHistory(numTriggersInThresholdHistoryLocal);
    }
}

- (UInt32)numTriggersInThresholdHistory
{
    if (dspThresholder)
    {
        return dspThresholder->GetNumTriggersInHistory();
    }
    else
    {
        return 0;
    }
}

@end
